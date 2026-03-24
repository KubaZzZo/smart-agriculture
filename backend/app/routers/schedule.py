from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import ScheduledTask, Device, DeviceLog
from ..schemas import ScheduledTaskCreate, ScheduledTaskUpdate, ScheduledTaskResponse

router = APIRouter()


def calc_next_run(cron_expr: str, repeat_type: str) -> datetime:
    """根据 cron 表达式和重复类型计算下次执行时间"""
    now = datetime.now()
    try:
        parts = cron_expr.split()
        minute = int(parts[0]) if len(parts) > 0 else 0
        hour = int(parts[1]) if len(parts) > 1 else 0
    except (ValueError, IndexError):
        minute, hour = 0, 8

    next_time = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if next_time <= now:
        if repeat_type == "daily":
            next_time += timedelta(days=1)
        elif repeat_type == "weekly":
            next_time += timedelta(weeks=1)
        else:
            next_time += timedelta(days=1)
    return next_time


@router.get("/tasks", response_model=list[ScheduledTaskResponse])
def list_tasks(db: Session = Depends(get_db)):
    return db.query(ScheduledTask).order_by(ScheduledTask.id.desc()).all()


@router.post("/tasks", response_model=ScheduledTaskResponse)
def create_task(body: ScheduledTaskCreate, db: Session = Depends(get_db)):
    device = db.query(Device).filter(Device.id == body.device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="设备不存在")

    task = ScheduledTask(
        task_name=body.task_name,
        device_id=body.device_id,
        action_type=body.action_type,
        action_params=body.action_params or {},
        cron_expr=body.cron_expr,
        repeat_type=body.repeat_type,
        is_enabled=body.is_enabled,
        next_run=calc_next_run(body.cron_expr, body.repeat_type),
    )
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@router.put("/tasks/{task_id}", response_model=ScheduledTaskResponse)
def update_task(task_id: int, body: ScheduledTaskUpdate, db: Session = Depends(get_db)):
    task = db.query(ScheduledTask).filter(ScheduledTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(task, field, value)

    if body.cron_expr or body.repeat_type:
        task.next_run = calc_next_run(
            task.cron_expr, task.repeat_type
        )

    db.commit()
    db.refresh(task)
    return task


@router.delete("/tasks/{task_id}")
def delete_task(task_id: int, db: Session = Depends(get_db)):
    task = db.query(ScheduledTask).filter(ScheduledTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")
    db.delete(task)
    db.commit()
    return {"detail": "已删除"}


def execute_scheduled_tasks(db: Session) -> list[dict]:
    """执行到期的定时任务，返回设备变更列表"""
    now = datetime.now()
    tasks = (
        db.query(ScheduledTask)
        .filter(ScheduledTask.is_enabled == 1, ScheduledTask.next_run <= now)
        .all()
    )
    changes = []
    for task in tasks:
        device = db.query(Device).filter(Device.id == task.device_id).first()
        if not device:
            continue

        if task.action_type == "on":
            device.status = 1
        elif task.action_type == "off":
            device.status = 0

        if task.action_params:
            device.params = {**(device.params or {}), **task.action_params}

        log = DeviceLog(
            device_id=device.id,
            action=f"定时{task.action_type}",
            params=task.action_params or {},
            source="schedule",
        )
        db.add(log)

        changes.append({
            "device_id": device.id,
            "device_name": device.device_name,
            "status": device.status,
            "task_name": task.task_name,
        })

        if task.repeat_type == "once":
            task.is_enabled = 0
            task.next_run = None
        else:
            task.next_run = calc_next_run(task.cron_expr, task.repeat_type)

    if changes:
        db.commit()
    return changes
