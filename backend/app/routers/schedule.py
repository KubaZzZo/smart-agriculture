from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Device, DeviceLog, ScheduledTask
from ..schemas import ScheduledTaskCreate, ScheduledTaskResponse, ScheduledTaskUpdate

router = APIRouter()
ALLOWED_REPEAT_TYPES = {'once', 'daily', 'weekly'}
ALLOWED_ACTION_TYPES = {'on', 'off', 'set'}


def calc_next_run(cron_expr: str, repeat_type: str) -> datetime:
    """Compute next run time from a simplified cron expression."""
    now = datetime.now()
    try:
        parts = cron_expr.split()
        minute = int(parts[0]) if len(parts) > 0 else 0
        hour = int(parts[1]) if len(parts) > 1 else 0
        if minute < 0 or minute > 59 or hour < 0 or hour > 23:
            raise ValueError("invalid hour/minute range")
    except (ValueError, IndexError):
        minute, hour = 0, 8

    next_time = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if next_time <= now:
        if repeat_type == 'daily':
            next_time += timedelta(days=1)
        elif repeat_type == 'weekly':
            next_time += timedelta(weeks=1)
        else:
            next_time += timedelta(days=1)
    return next_time


def _validate_task_inputs(action_type: str, repeat_type: str) -> None:
    if action_type not in ALLOWED_ACTION_TYPES:
        raise HTTPException(status_code=400, detail='invalid action_type')
    if repeat_type not in ALLOWED_REPEAT_TYPES:
        raise HTTPException(status_code=400, detail='invalid repeat_type')


@router.get('/tasks', response_model=list[ScheduledTaskResponse])
def list_tasks(db: Session = Depends(get_db)):
    return db.query(ScheduledTask).order_by(ScheduledTask.id.desc()).all()


@router.post('/tasks', response_model=ScheduledTaskResponse)
def create_task(body: ScheduledTaskCreate, db: Session = Depends(get_db)):
    _validate_task_inputs(body.action_type, body.repeat_type)

    device = db.query(Device).filter(Device.id == body.device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail='device not found')

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
    try:
        db.add(task)
        db.commit()
        db.refresh(task)
        return task
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail='invalid scheduled task')


@router.put('/tasks/{task_id}', response_model=ScheduledTaskResponse)
def update_task(task_id: int, body: ScheduledTaskUpdate, db: Session = Depends(get_db)):
    task = db.query(ScheduledTask).filter(ScheduledTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail='task not found')

    payload = body.model_dump(exclude_unset=True)
    action_type = payload.get('action_type', task.action_type)
    repeat_type = payload.get('repeat_type', task.repeat_type)
    _validate_task_inputs(action_type, repeat_type)
    if 'device_id' in payload:
        device = db.query(Device).filter(Device.id == payload['device_id']).first()
        if not device:
            raise HTTPException(status_code=404, detail='device not found')

    for field, value in payload.items():
        setattr(task, field, value)

    if body.cron_expr or body.repeat_type:
        task.next_run = calc_next_run(task.cron_expr, task.repeat_type)

    try:
        db.commit()
        db.refresh(task)
        return task
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail='invalid scheduled task')


@router.delete('/tasks/{task_id}')
def delete_task(task_id: int, db: Session = Depends(get_db)):
    task = db.query(ScheduledTask).filter(ScheduledTask.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail='task not found')

    db.delete(task)
    db.commit()
    return {'detail': 'task deleted'}


def execute_scheduled_tasks(db: Session) -> list[dict]:
    """Execute due scheduled tasks and return changed devices."""
    now = datetime.now()
    tasks = (
        db.query(ScheduledTask)
        .filter(ScheduledTask.is_enabled == 1, ScheduledTask.next_run <= now)
        .all()
    )

    changes: list[dict] = []
    missing_device_task_ids: list[int] = []
    for task in tasks:
        device = db.query(Device).filter(Device.id == task.device_id).first()
        if not device:
            # Disable tasks that target deleted devices to avoid endless retries.
            task.is_enabled = 0
            task.next_run = None
            missing_device_task_ids.append(task.id)
            continue

        if task.action_type == 'on':
            device.status = 1
        elif task.action_type == 'off':
            device.status = 0

        if task.action_params:
            device.params = {**(device.params or {}), **task.action_params}

        db.add(
            DeviceLog(
                device_id=device.id,
                action=f'scheduled_{task.action_type}',
                params=task.action_params or {},
                source='schedule',
            )
        )

        changes.append(
            {
                'device_id': device.id,
                'device_name': device.device_name,
                'status': device.status,
                'task_name': task.task_name,
            }
        )

        if task.repeat_type == 'once':
            task.is_enabled = 0
            task.next_run = None
        else:
            task.next_run = calc_next_run(task.cron_expr, task.repeat_type)

    if changes or missing_device_task_ids:
        db.commit()
    return changes
