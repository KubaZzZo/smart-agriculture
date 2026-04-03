from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import AlertLog, DailyReport, Device, DeviceLog, SensorData, WaterUsage
from ..schemas import DailyReportResponse

router = APIRouter()


def generate_daily_report(db: Session, date_str: str = None) -> DailyReport:
    if not date_str:
        date_str = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')

    existing = db.query(DailyReport).filter(DailyReport.report_date == date_str).first()
    if existing:
        return existing

    day_start = datetime.strptime(date_str, '%Y-%m-%d')
    day_end = day_start + timedelta(days=1)

    row = (
        db.query(
            func.avg(SensorData.temperature),
            func.avg(SensorData.humidity),
            func.avg(SensorData.light_intensity),
            func.avg(SensorData.co2_level),
            func.avg(SensorData.soil_moisture),
        )
        .filter(SensorData.created_at.between(day_start, day_end))
        .first()
    )

    alert_count = db.query(AlertLog).filter(AlertLog.created_at.between(day_start, day_end)).count()

    irrigation_count = (
        db.query(DeviceLog)
        .join(Device, DeviceLog.device_id == Device.id)
        .filter(
            DeviceLog.created_at.between(day_start, day_end),
            Device.device_type.in_(['pump', 'valve']),
        )
        .count()
    )

    water_total = (
        db.query(func.coalesce(func.sum(WaterUsage.usage_liters), 0))
        .filter(WaterUsage.usage_date == date_str)
        .scalar()
    )

    avg_t = round(row[0] or 0, 1)
    avg_h = round(row[1] or 0, 1)
    avg_l = round(row[2] or 0, 1)
    avg_c = round(row[3] or 0, 1)
    avg_s = round(row[4] or 0, 1)

    summary = (
        f"{date_str} report: avg temp={avg_t}C, humidity={avg_h}%, light={avg_l}lux, "
        f"co2={avg_c}ppm, soil={avg_s}%. alerts={alert_count}, "
        f"irrigation_ops={irrigation_count}, water={round(water_total, 1)}L."
    )

    report = DailyReport(
        report_date=date_str,
        avg_temperature=avg_t,
        avg_humidity=avg_h,
        avg_light=avg_l,
        avg_co2=avg_c,
        avg_soil_moisture=avg_s,
        alert_count=alert_count,
        irrigation_count=irrigation_count,
        water_usage=round(water_total, 1),
        summary=summary,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


@router.get('', response_model=list[DailyReportResponse])
def list_reports(
    limit: int = Query(30, ge=1, le=90),
    db: Session = Depends(get_db),
):
    return db.query(DailyReport).order_by(DailyReport.report_date.desc()).limit(limit).all()


@router.post('/generate', response_model=DailyReportResponse)
def trigger_report(
    date: str = Query(None, description='date in YYYY-MM-DD, default is yesterday'),
    db: Session = Depends(get_db),
):
    if date:
        try:
            datetime.strptime(date, '%Y-%m-%d')
        except ValueError as exc:
            raise HTTPException(status_code=400, detail='invalid date format, use YYYY-MM-DD') from exc
    return generate_daily_report(db, date)
