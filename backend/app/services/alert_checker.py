from sqlalchemy.orm import Session
from ..models import AlertRule, AlertLog, SensorData


METRIC_MAP = {
    "temperature": "temperature",
    "humidity": "humidity",
    "light_intensity": "light_intensity",
    "co2_level": "co2_level",
    "soil_moisture": "soil_moisture",
}


def check_alerts(db: Session, sensor_data: SensorData) -> list[dict]:
    """检查所有启用的预警规则，返回触发的预警列表"""
    triggered = []
    rules = db.query(AlertRule).filter(AlertRule.is_enabled == 1).all()

    for rule in rules:
        attr_name = METRIC_MAP.get(rule.metric_name)
        if not attr_name:
            continue
        value = getattr(sensor_data, attr_name, None)
        if value is None:
            continue

        alert_type = None
        if value > rule.max_value:
            alert_type = "high"
        elif value < rule.min_value:
            alert_type = "low"

        if alert_type:
            log = AlertLog(
                rule_id=rule.id,
                metric_name=rule.metric_name,
                metric_value=value,
                alert_type=alert_type,
            )
            db.add(log)
            db.commit()
            db.refresh(log)
            triggered.append({
                "id": log.id,
                "rule_id": log.rule_id,
                "metric_name": log.metric_name,
                "metric_value": log.metric_value,
                "alert_type": log.alert_type,
                "created_at": log.created_at.isoformat() if log.created_at else None,
            })

    return triggered
