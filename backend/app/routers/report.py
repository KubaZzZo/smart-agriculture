from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from ..database import get_db
from ..models import DailyReport, SensorData, AlertLog, DeviceLog, WaterUsage, Device
from ..schemas import DailyReportResponse

router = APIRouter()


def generate_daily_report(db: Session, date_str: str = None) -> DailyReport:
    """生成指定日期的每日报告"""
    if not date_str:
        date_str = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")

    existing = db.query(DailyReport).filter(DailyReport.report_date == date_str).first()
    if existing:
        return existing

    day_start = datetime.strptime(date_str, "%Y-%m-%d")
    day_end = day_start + timedelta(days=1)

    row = db.query(
        func.avg(SensorData.temperature),
        func.avg(SensorData.humidity),
        func.avg(SensorData.light_intensity),
        func.avg(SensorData.co2_level),
        func.avg(SensorData.soil_moisture),
    ).filter(SensorData.created_at.between(day_start, day_end)).first()

    alert_count = db.query(AlertLog).filter(
        AlertLog.created_at.between(day_start, day_end)
    ).count()

    irrigation_count = db.query(DeviceLog).join(
        Device, DeviceLog.device_id == Device.id
    ).filter(
        DeviceLog.created_at.between(day_start, day_end),
        Device.device_type.in_(["pump", "valve"]),
    ).count()

    water_total = db.query(func.coalesce(func.sum(WaterUsage.usage_liters), 0)).filter(
        WaterUsage.usage_date == date_str
    ).scalar()

    avg_t = round(row[0] or 0, 1)
    avg_h = round(row[1] or 0, 1)
    avg_l = round(row[2] or 0, 1)
    avg_c = round(row[3] or 0, 1)
    avg_s = round(row[4] or 0, 1)

    summary = (
        f"{date_str} 日报: 平均温度{avg_t}℃, 湿度{avg_h}%, "
        f"光照{avg_l}lux, CO₂{avg_c}ppm, 土壤湿度{avg_s}%. "
        f"触发预警{alert_count}次, 灌溉操作{irrigation_count}次, "
        f"用水{round(water_total, 1)}L."
    )

    report = DailyReport(
        report_date=date_str,
        avg_temperature=avg_t, avg_humidity=avg_h,
        avg_light=avg_l, avg_co2=avg_c, avg_soil_moisture=avg_s,
        alert_count=alert_count, irrigation_count=irrigation_count,
        water_usage=round(water_total, 1), summary=summary,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


@router.get("", response_model=list[DailyReportResponse])
def list_reports(
    limit: int = Query(30, ge=1, le=90),
    db: Session = Depends(get_db),
):
    return (
        db.query(DailyReport)
        .order_by(DailyReport.report_date.desc())
        .limit(limit)
        .all()
    )


@router.post("/generate", response_model=DailyReportResponse)
def trigger_report(
    date: str = Query(None, description="日期 YYYY-MM-DD，默认昨天"),
    db: Session = Depends(get_db),
):
    return generate_daily_report(db, date)
