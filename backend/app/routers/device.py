from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc, func
from ..database import get_db
from ..models import Device, DeviceLog
from ..schemas import (
    DeviceResponse, DeviceControlRequest, DeviceParamsRequest,
    DeviceLogResponse, DeviceLogListResponse,
    BatchControlRequest, DeviceHealthResponse,
)

router = APIRouter()


@router.get("/list", response_model=list[DeviceResponse])
def get_devices(db: Session = Depends(get_db)):
    return db.query(Device).all()


@router.post("/{device_id}/control", response_model=DeviceResponse)
def control_device(device_id: int, req: DeviceControlRequest, db: Session = Depends(get_db)):
    device = db.query(Device).filter(Device.id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="设备不存在")
    device.status = req.status
    db.add(DeviceLog(
        device_id=device_id,
        action="on" if req.status == 1 else "off",
        params={},
        source="manual",
    ))
    db.commit()
    db.refresh(device)
    return device


@router.post("/{device_id}/params", response_model=DeviceResponse)
def set_device_params(device_id: int, req: DeviceParamsRequest, db: Session = Depends(get_db)):
    device = db.query(Device).filter(Device.id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="设备不存在")
    device.params = req.params
    db.add(DeviceLog(
        device_id=device_id,
        action="set",
        params=req.params,
        source="manual",
    ))
    db.commit()
    db.refresh(device)
    return device


@router.get("/{device_id}/logs", response_model=DeviceLogListResponse)
def get_device_logs(
    device_id: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    query = db.query(DeviceLog).filter(DeviceLog.device_id == device_id)
    total = query.count()
    items = (
        query.order_by(desc(DeviceLog.created_at))
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return DeviceLogListResponse(total=total, page=page, page_size=page_size, items=items)


@router.post("/batch-control")
def batch_control(req: BatchControlRequest, db: Session = Depends(get_db)):
    devices = db.query(Device).filter(Device.id.in_(req.device_ids)).all()
    changed = []
    for device in devices:
        device.status = req.status
        db.add(DeviceLog(
            device_id=device.id,
            action="on" if req.status == 1 else "off",
            params={},
            source="manual",
        ))
        changed.append(device.device_name)
    db.commit()
    return {"detail": f"已批量{'开启' if req.status == 1 else '关闭'}: {', '.join(changed)}"}


@router.get("/health", response_model=list[DeviceHealthResponse])
def get_device_health(db: Session = Depends(get_db)):
    devices = db.query(Device).all()
    week_ago = datetime.now() - timedelta(days=7)
    result = []
    for d in devices:
        logs = db.query(DeviceLog).filter(
            DeviceLog.device_id == d.id,
            DeviceLog.created_at >= week_ago,
        )
        total_ops = logs.count()
        error_count = logs.filter(DeviceLog.action.like("%error%")).count()

        # 计算在线时长（基于操作日志估算）
        on_logs = logs.filter(DeviceLog.action == "on").count()
        off_logs = logs.filter(DeviceLog.action == "off").count()
        uptime_hours = round(on_logs * 2.5, 1)  # 估算每次开启平均运行2.5小时

        # 离线次数
        offline_count = off_logs

        # 健康评分: 基础80分，有错误扣分，操作频繁加分
        score = 80
        score -= error_count * 10
        if total_ops > 5:
            score += 10
        if d.status == 1:
            score += 10
        score = max(0, min(100, score))

        result.append(DeviceHealthResponse(
            device_id=d.id,
            device_name=d.device_name,
            device_type=d.device_type,
            uptime_hours=uptime_hours,
            offline_count=offline_count,
            error_count=error_count,
            health_score=score,
            status=d.status,
        ))
    return result
