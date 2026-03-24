from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from ..database import get_db
from ..models import WaterUsage, DeviceLog
from ..schemas import WaterUsageResponse, WaterDailySummary

router = APIRouter()


@router.get("/daily", response_model=list[WaterDailySummary])
def get_daily_water(
    days: int = Query(7, ge=1, le=90),
    db: Session = Depends(get_db),
):
    results = (
        db.query(
            WaterUsage.usage_date,
            func.sum(WaterUsage.usage_liters).label("total_liters"),
            func.sum(WaterUsage.duration_seconds).label("total_seconds"),
        )
        .group_by(WaterUsage.usage_date)
        .order_by(WaterUsage.usage_date.desc())
        .limit(days)
        .all()
    )
    return [
        WaterDailySummary(date=r.usage_date, total_liters=round(r.total_liters, 1), total_seconds=r.total_seconds)
        for r in results
    ]


@router.get("/today")
def get_today_water(db: Session = Depends(get_db)):
    today = datetime.now().strftime("%Y-%m-%d")
    total = db.query(func.coalesce(func.sum(WaterUsage.usage_liters), 0)).filter(
        WaterUsage.usage_date == today
    ).scalar()
    return {"date": today, "total_liters": round(total, 1)}


def record_water_usage(db: Session, device_id: int, duration_seconds: int, flow_rate: float = 2.0):
    """记录一次用水（由设备控制时调用）"""
    usage_liters = round(flow_rate * duration_seconds / 60, 2)
    today = datetime.now().strftime("%Y-%m-%d")
    record = WaterUsage(
        device_id=device_id,
        usage_liters=usage_liters,
        duration_seconds=duration_seconds,
        usage_date=today,
    )
    db.add(record)
    db.commit()
    return record
