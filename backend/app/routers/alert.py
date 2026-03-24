from typing import Optional
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc, func
from ..database import get_db
from ..models import AlertRule, AlertLog
from ..schemas import (
    AlertRuleCreate, AlertRuleUpdate, AlertRuleResponse,
    AlertLogResponse, AlertLogListResponse,
    AlertStatsItem, AlertStatsResponse,
)

router = APIRouter()


# --- Alert Rules ---
@router.get("/rules", response_model=list[AlertRuleResponse])
def get_rules(db: Session = Depends(get_db)):
    return db.query(AlertRule).all()


@router.post("/rules", response_model=AlertRuleResponse)
def create_rule(req: AlertRuleCreate, db: Session = Depends(get_db)):
    rule = AlertRule(**req.model_dump())
    db.add(rule)
    db.commit()
    db.refresh(rule)
    return rule


@router.put("/rules/{rule_id}", response_model=AlertRuleResponse)
def update_rule(rule_id: int, req: AlertRuleUpdate, db: Session = Depends(get_db)):
    rule = db.query(AlertRule).filter(AlertRule.id == rule_id).first()
    if not rule:
        raise HTTPException(status_code=404, detail="规则不存在")
    for key, value in req.model_dump(exclude_unset=True).items():
        setattr(rule, key, value)
    db.commit()
    db.refresh(rule)
    return rule


@router.delete("/rules/{rule_id}")
def delete_rule(rule_id: int, db: Session = Depends(get_db)):
    rule = db.query(AlertRule).filter(AlertRule.id == rule_id).first()
    if not rule:
        raise HTTPException(status_code=404, detail="规则不存在")
    db.delete(rule)
    db.commit()
    return {"message": "删除成功"}


# --- Alert Logs ---
@router.get("/logs", response_model=AlertLogListResponse)
def get_logs(
    is_read: Optional[int] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    query = db.query(AlertLog)
    if is_read is not None:
        query = query.filter(AlertLog.is_read == is_read)
    total = query.count()
    items = (
        query.order_by(desc(AlertLog.created_at))
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return AlertLogListResponse(total=total, page=page, page_size=page_size, items=items)


@router.post("/logs/{log_id}/read")
def mark_read(log_id: int, db: Session = Depends(get_db)):
    log = db.query(AlertLog).filter(AlertLog.id == log_id).first()
    if not log:
        raise HTTPException(status_code=404, detail="记录不存在")
    log.is_read = 1
    db.commit()
    return {"message": "已标记已读"}


@router.post("/logs/read-all")
def mark_all_read(db: Session = Depends(get_db)):
    db.query(AlertLog).filter(AlertLog.is_read == 0).update({"is_read": 1})
    db.commit()
    return {"message": "全部标记已读"}


@router.get("/stats", response_model=AlertStatsResponse)
def get_alert_stats(
    period: str = Query("day", description="统计周期: day / week / month"),
    db: Session = Depends(get_db),
):
    now = datetime.now()
    if period == "month":
        start = now - timedelta(days=30)
    elif period == "week":
        start = now - timedelta(days=7)
    else:
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    metrics = ["temperature", "humidity", "light_intensity", "co2_level", "soil_moisture"]
    items = []
    for m in metrics:
        high = db.query(AlertLog).filter(
            AlertLog.created_at >= start,
            AlertLog.metric_name == m,
            AlertLog.alert_type == "high",
        ).count()
        low = db.query(AlertLog).filter(
            AlertLog.created_at >= start,
            AlertLog.metric_name == m,
            AlertLog.alert_type == "low",
        ).count()
        items.append(AlertStatsItem(
            metric_name=m, high_count=high, low_count=low, total=high + low,
        ))

    return AlertStatsResponse(period=period, items=items)
