from datetime import datetime, timedelta
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from ..database import get_db
from ..models import Device, AlertLog, SensorData
from ..schemas import SystemOverviewResponse, SensorDataResponse

router = APIRouter()


@router.get("/overview", response_model=SystemOverviewResponse)
def get_overview(db: Session = Depends(get_db)):
    device_total = db.query(Device).count()
    device_online = db.query(Device).filter(Device.status == 1).count()

    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    alert_today = (
        db.query(AlertLog)
        .filter(AlertLog.created_at >= today_start)
        .count()
    )

    latest = db.query(SensorData).order_by(SensorData.id.desc()).first()
    latest_sensor = None
    if latest:
        latest_sensor = SensorDataResponse.model_validate(latest)

    return SystemOverviewResponse(
        device_total=device_total,
        device_online=device_online,
        alert_today=alert_today,
        latest_sensor=latest_sensor,
    )
