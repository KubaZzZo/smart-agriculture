import asyncio
import os
from contextlib import asynccontextmanager
from datetime import datetime as dt, timedelta as td
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import desc
from .database import engine, Base, SessionLocal
from .models import SensorData, Device as DeviceModel
from .routers import sensor, device, alert, automation, camera, system, schedule, zone, auth, crop, report, water, weather
from .routers.schedule import execute_scheduled_tasks
from .routers.water import record_water_usage
from .routers.report import generate_daily_report
from .websocket import manager
from .services.simulator import generate_sensor_data
from .services.alert_checker import check_alerts
from .services.automation_engine import execute_automations
from .config import settings
from .services.mqtt_client import start_mqtt

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
    start_mqtt()                                    # 启动 Easy IoT MQTT 订阅
    task = asyncio.create_task(simulation_loop())
    yield
    task.cancel()


app = FastAPI(title="Smart Agriculture API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files
os.makedirs("static", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

# Routers
app.include_router(sensor.router, prefix="/api/sensor", tags=["sensor"])
app.include_router(device.router, prefix="/api/device", tags=["device"])
app.include_router(alert.router, prefix="/api/alert", tags=["alert"])
app.include_router(automation.router, prefix="/api/automation", tags=["automation"])
app.include_router(camera.router, prefix="/api/camera", tags=["camera"])
app.include_router(system.router, prefix="/api/system", tags=["system"])
app.include_router(schedule.router, prefix="/api/schedule", tags=["schedule"])
app.include_router(zone.router, prefix="/api/zone", tags=["zone"])
app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(crop.router, prefix="/api/crop", tags=["crop"])
app.include_router(report.router, prefix="/api/report", tags=["report"])
app.include_router(water.router, prefix="/api/water", tags=["water"])
app.include_router(weather.router, prefix="/api/weather", tags=["weather"])


@app.websocket("/ws/realtime")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)


@app.get("/")
def root():
    return {"message": "Smart Agriculture API", "version": "1.0.0"}
