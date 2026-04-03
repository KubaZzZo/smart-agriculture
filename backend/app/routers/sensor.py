import csv
from datetime import datetime, timedelta
from io import StringIO
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import desc, func
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import SensorData
from ..schemas import MetricStatsResponse, SensorDataResponse, SensorHistoryResponse, StatsResponse

router = APIRouter()

METRIC_COLUMNS = {
    'temperature': SensorData.temperature,
    'humidity': SensorData.humidity,
    'light_intensity': SensorData.light_intensity,
    'co2_level': SensorData.co2_level,
    'soil_moisture': SensorData.soil_moisture,
}


@router.get('/realtime', response_model=Optional[SensorDataResponse])
def get_realtime(db: Session = Depends(get_db)):
    return db.query(SensorData).order_by(desc(SensorData.id)).first()


@router.get('/history', response_model=SensorHistoryResponse)
def get_history(
    metric: Optional[str] = Query(None, description='optional metric filter'),
    start_time: Optional[datetime] = Query(None),
    end_time: Optional[datetime] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    if metric and metric not in METRIC_COLUMNS:
        raise HTTPException(status_code=400, detail='invalid metric')

    query = db.query(SensorData)
    if start_time:
        query = query.filter(SensorData.created_at >= start_time)
    if end_time:
        query = query.filter(SensorData.created_at <= end_time)

    total = query.count()
    items = (
        query.order_by(desc(SensorData.created_at))
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return SensorHistoryResponse(total=total, page=page, page_size=page_size, items=items)


@router.get('/stats', response_model=StatsResponse)
def get_stats(
    period: str = Query('day', description='aggregation period: day / week'),
    db: Session = Depends(get_db),
):
    now = datetime.now()
    if period == 'week':
        start = now - timedelta(days=7)
    else:
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    latest = db.query(SensorData).order_by(desc(SensorData.id)).first()

    metrics: list[MetricStatsResponse] = []
    for name, col in METRIC_COLUMNS.items():
        row = (
            db.query(
                func.avg(col).label('avg_val'),
                func.min(col).label('min_val'),
                func.max(col).label('max_val'),
            )
            .filter(SensorData.created_at >= start)
            .first()
        )
        latest_val = getattr(latest, name, 0) if latest else 0
        metrics.append(
            MetricStatsResponse(
                metric_name=name,
                avg_value=round(row.avg_val or 0, 1),
                min_value=round(row.min_val or 0, 1),
                max_value=round(row.max_val or 0, 1),
                latest_value=round(latest_val, 1),
            )
        )

    return StatsResponse(date=now.strftime('%Y-%m-%d'), metrics=metrics)


@router.get('/export')
def export_csv(
    start_time: Optional[datetime] = Query(None),
    end_time: Optional[datetime] = Query(None),
    db: Session = Depends(get_db),
):
    query = db.query(SensorData)
    if start_time:
        query = query.filter(SensorData.created_at >= start_time)
    if end_time:
        query = query.filter(SensorData.created_at <= end_time)
    items = query.order_by(desc(SensorData.created_at)).limit(5000).all()

    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(['timestamp', 'temperature(c)', 'humidity(%)', 'light(lux)', 'co2(ppm)', 'soil_moisture(%)'])
    for item in items:
        writer.writerow(
            [
                item.created_at.strftime('%Y-%m-%d %H:%M:%S') if item.created_at else '',
                round(item.temperature, 1),
                round(item.humidity, 1),
                round(item.light_intensity, 1),
                round(item.co2_level, 1),
                round(item.soil_moisture, 1),
            ]
        )
    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type='text/csv',
        headers={'Content-Disposition': 'attachment; filename=sensor_data.csv'},
    )
