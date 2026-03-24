from sqlalchemy.orm import Session
from ..models import AutomationRule, Device, DeviceLog, SensorData


METRIC_MAP = {
    "temperature": "temperature",
    "humidity": "humidity",
    "light_intensity": "light_intensity",
    "co2_level": "co2_level",
    "soil_moisture": "soil_moisture",
}


def evaluate_condition(value: float, condition: str, threshold: float) -> bool:
    if condition == "gt":
        return value > threshold
    elif condition == "lt":
        return value < threshold
    elif condition == "eq":
        return abs(value - threshold) < 0.01
    return False


def execute_automations(db: Session, sensor_data: SensorData) -> list[dict]:
    """执行所有启用的联动规则，返回设备变更列表"""
    changes = []
    rules = db.query(AutomationRule).filter(AutomationRule.is_enabled == 1).all()

    for rule in rules:
        attr_name = METRIC_MAP.get(rule.trigger_metric)
        if not attr_name:
            continue
        value = getattr(sensor_data, attr_name, None)
        if value is None:
            continue

        if not evaluate_condition(value, rule.trigger_condition, rule.trigger_value):
            continue

        device = db.query(Device).filter(Device.id == rule.action_device_id).first()
        if not device:
            continue

        changed = False
        if rule.action_type == "on" and device.status != 1:
            device.status = 1
            changed = True
        elif rule.action_type == "off" and device.status != 0:
            device.status = 0
            changed = True
        elif rule.action_type == "set":
            if rule.action_params and rule.action_params != device.params:
                device.params = rule.action_params
                device.status = 1
                changed = True

        if changed:
            db.add(DeviceLog(
                device_id=device.id,
                action=rule.action_type,
                params=rule.action_params or {},
                source="automation",
            ))
            db.commit()
            db.refresh(device)
            changes.append({
                "device_id": device.id,
                "device_name": device.device_name,
                "device_type": device.device_type,
                "status": device.status,
                "params": device.params,
                "action": rule.action_type,
            })

    return changes
