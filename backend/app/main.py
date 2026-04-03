import asyncio
import logging
import os
from pathlib import Path
from contextlib import asynccontextmanager
from datetime import datetime as dt, timedelta as td
from fastapi import Depends, FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from starlette import status
from sqlalchemy import desc
from .database import engine, Base, SessionLocal
from .models import SensorData, Device as DeviceModel
from .routers import (
    sensor,
    device,
    alert,
    automation,
    camera,
    system,
    schedule,
    zone,
    auth,
    crop,
    report,
    water,
    weather,
    ai_ops,
)
from .routers.auth import get_current_user, get_user_from_token
from .routers.schedule import execute_scheduled_tasks
from .routers.water import record_water_usage
from .routers.report import generate_daily_report
from .websocket import manager
from .services.simulator import generate_sensor_data
from .services.alert_checker import check_alerts
from .services.automation_engine import execute_automations
from .services.edge_autonomy import edge_autonomy_service
from .services.edge_task_executor import execute_edge_task
from .config import settings

# 每日报告计数器（每天生成一次）
_last_report_date = ""


async def simulation_loop():
    """后台模拟循环：每5秒生成数据、检查预警、执行联动"""
    while True:
        db = SessionLocal()
        try:
            # 获取上一条数据
            last_data = db.query(SensorData).order_by(desc(SensorData.id)).first()

            # 1. 生成新传感器数据
            new_data = generate_sensor_data(db, last_data)

            # 2. 检查预警
            alerts = check_alerts(db, new_data)

            # 3. 执行联动自动化
            device_changes = execute_automations(db, new_data)

            # 4. 执行到期的定时任务
            schedule_changes = execute_scheduled_tasks(db)

            # 5. 记录用水量（水泵/水阀运行时自动记录）
            water_devices = db.query(DeviceModel).filter(
                DeviceModel.device_type.in_(["pump", "valve"]),
                DeviceModel.status == 1,
            ).all()
            for wd in water_devices:
                flow_rate = (wd.params or {}).get("flow_rate", 2.0) or 2.0
                record_water_usage(db, wd.id, settings.SIMULATE_INTERVAL, float(flow_rate))

            # 6. 每日报告自动生成（每天第一次循环时生成昨天的报告）
            global _last_report_date
            today_str = dt.now().strftime("%Y-%m-%d")
            if _last_report_date != today_str:
                _last_report_date = today_str
                yesterday = (dt.now() - td(days=1)).strftime("%Y-%m-%d")
                try:
                    generate_daily_report(db, yesterday)
                except Exception:
                    pass

            # 提取数据用于广播（在 db.close() 之前）
            broadcast_data = {
                "id": new_data.id,
                "temperature": new_data.temperature,
                "humidity": new_data.humidity,
                "light_intensity": new_data.light_intensity,
                "co2_level": new_data.co2_level,
                "soil_moisture": new_data.soil_moisture,
                "created_at": new_data.created_at.isoformat() if new_data.created_at else None,
            }

        except Exception as e:
            print(f"[Simulator Error] {e}")
            alerts, device_changes, schedule_changes, broadcast_data = [], [], [], None
        finally:
            db.close()

        # 7. WebSocket 广播（在 db 关闭后安全发送）
        try:
            if broadcast_data:
                await manager.broadcast({"type": "sensor_data", "data": broadcast_data})

            if alerts:
                await manager.broadcast({"type": "alert", "data": alerts})

            if device_changes:
                await manager.broadcast({"type": "device_status", "data": device_changes})

            if schedule_changes:
                await manager.broadcast({"type": "device_status", "data": schedule_changes})
        except Exception as e:
            print(f"[Broadcast Error] {e}")

        await asyncio.sleep(settings.SIMULATE_INTERVAL)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    Base.metadata.create_all(bind=engine)
    task = asyncio.create_task(simulation_loop())
    yield
    task.cancel()


app = FastAPI(title="Smart Agriculture API", version="1.0.0", lifespan=lifespan)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)

# Bind real edge task executor (device status + logs persistence).
edge_autonomy_service.set_executor(execute_edge_task)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files (resolve path from backend root to avoid cwd issues)
BACKEND_DIR = Path(__file__).resolve().parents[1]
STATIC_DIR = BACKEND_DIR / "static"
STATIC_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

# Routers
app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(
    sensor.router, prefix="/api/sensor", tags=["sensor"], dependencies=[Depends(get_current_user)]
)
app.include_router(
    device.router, prefix="/api/device", tags=["device"], dependencies=[Depends(get_current_user)]
)
app.include_router(
    alert.router, prefix="/api/alert", tags=["alert"], dependencies=[Depends(get_current_user)]
)
app.include_router(
    automation.router,
    prefix="/api/automation",
    tags=["automation"],
    dependencies=[Depends(get_current_user)],
)
app.include_router(
    camera.router, prefix="/api/camera", tags=["camera"], dependencies=[Depends(get_current_user)]
)
app.include_router(
    system.router, prefix="/api/system", tags=["system"], dependencies=[Depends(get_current_user)]
)
app.include_router(
    schedule.router, prefix="/api/schedule", tags=["schedule"], dependencies=[Depends(get_current_user)]
)
app.include_router(
    zone.router, prefix="/api/zone", tags=["zone"], dependencies=[Depends(get_current_user)]
)
app.include_router(
    crop.router, prefix="/api/crop", tags=["crop"], dependencies=[Depends(get_current_user)]
)
app.include_router(
    report.router, prefix="/api/report", tags=["report"], dependencies=[Depends(get_current_user)]
)
app.include_router(
    water.router, prefix="/api/water", tags=["water"], dependencies=[Depends(get_current_user)]
)
app.include_router(weather.router, prefix="/api/weather", tags=["weather"])
app.include_router(ai_ops.router, prefix="/api/ai", tags=["ai"])


@app.websocket("/ws/realtime")
async def websocket_endpoint(websocket: WebSocket):
    auth_header = websocket.headers.get("authorization", "")
    token = ""
    if auth_header.startswith("Bearer "):
        token = auth_header.replace("Bearer ", "", 1).strip()
    if not token:
        token = websocket.query_params.get("token", "").strip()

    db = SessionLocal()
    try:
        user = get_user_from_token(token, db) if token else None
    finally:
        db.close()

    if not user:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)


@app.get("/")
def root():
    return {
        "message": "Smart Agriculture API",
        "version": "1.0.0",
        "ai_ops_web": "/ai-ops",
        "static_ai_ops_web": "/static/ai-ops/index.html",
        "dashboard_web": "/dashboard",
        "static_dashboard_web": "/static/dashboard/index.html",
    }


@app.get("/ai-ops")
def ai_ops_web():
    page = STATIC_DIR / "ai-ops" / "index.html"
    if not page.exists():
        return {"error": "ai_ops_page_not_found", "path": str(page)}
    return FileResponse(str(page))


@app.get("/dashboard")
def dashboard_web():
    page = STATIC_DIR / "dashboard" / "index.html"
    if not page.exists():
        return {"error": "dashboard_page_not_found", "path": str(page)}
    return FileResponse(str(page))
