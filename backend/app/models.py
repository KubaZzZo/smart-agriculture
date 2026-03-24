from sqlalchemy import Column, Integer, BigInteger, Float, String, Text, DateTime, SmallInteger, JSON, ForeignKey
from sqlalchemy.sql import func
from .database import Base


class SensorData(Base):
    __tablename__ = "sensor_data"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    temperature = Column(Float, nullable=False)
    humidity = Column(Float, nullable=False)
    light_intensity = Column(Float, nullable=False)
    co2_level = Column(Float, nullable=False)
    soil_moisture = Column(Float, nullable=False)
    created_at = Column(DateTime, server_default=func.now())


class Device(Base):
    __tablename__ = "device"

    id = Column(Integer, primary_key=True, autoincrement=True)
    device_name = Column(String(100), nullable=False)
    device_type = Column(String(50), nullable=False)
    status = Column(SmallInteger, default=0)
    params = Column(JSON, default=dict)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class AlertRule(Base):
    __tablename__ = "alert_rule"

    id = Column(Integer, primary_key=True, autoincrement=True)
    metric_name = Column(String(30), nullable=False)
    min_value = Column(Float, nullable=False)
    max_value = Column(Float, nullable=False)
    is_enabled = Column(SmallInteger, default=1)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class AlertLog(Base):
    __tablename__ = "alert_log"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    rule_id = Column(Integer, ForeignKey("alert_rule.id"), nullable=False)
    metric_name = Column(String(30), nullable=False)
    metric_value = Column(Float, nullable=False)
    alert_type = Column(String(10), nullable=False)
    is_read = Column(SmallInteger, default=0)
    created_at = Column(DateTime, server_default=func.now())


class AutomationRule(Base):
    __tablename__ = "automation_rule"

    id = Column(Integer, primary_key=True, autoincrement=True)
    trigger_metric = Column(String(30), nullable=False)
    trigger_condition = Column(String(10), nullable=False)
    trigger_value = Column(Float, nullable=False)
    action_device_id = Column(Integer, ForeignKey("device.id"), nullable=False)
    action_type = Column(String(10), nullable=False)
    action_params = Column(JSON, default=dict)
    is_enabled = Column(SmallInteger, default=1)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class DeviceLog(Base):
    __tablename__ = "device_log"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(Integer, ForeignKey("device.id"), nullable=False)
    action = Column(String(20), nullable=False)
    params = Column(JSON, default=dict)
    source = Column(String(20), nullable=False, default="manual")
    created_at = Column(DateTime, server_default=func.now())


class ScheduledTask(Base):
    __tablename__ = "scheduled_task"

    id = Column(Integer, primary_key=True, autoincrement=True)
    task_name = Column(String(100), nullable=False)
    device_id = Column(Integer, ForeignKey("device.id"), nullable=False)
    action_type = Column(String(10), nullable=False)
    action_params = Column(JSON, default=dict)
    cron_expr = Column(String(50), nullable=False)
    repeat_type = Column(String(20), nullable=False, default="once")
    is_enabled = Column(SmallInteger, default=1)
    next_run = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class Zone(Base):
    __tablename__ = "zone"

    id = Column(Integer, primary_key=True, autoincrement=True)
    zone_name = Column(String(100), nullable=False)
    zone_type = Column(String(30), nullable=False, default="greenhouse")
    description = Column(String(255), default="")
    is_active = Column(SmallInteger, default=1)
    created_at = Column(DateTime, server_default=func.now())


class ZoneDevice(Base):
    __tablename__ = "zone_device"

    id = Column(Integer, primary_key=True, autoincrement=True)
    zone_id = Column(Integer, ForeignKey("zone.id", ondelete="CASCADE"), nullable=False)
    device_id = Column(Integer, ForeignKey("device.id", ondelete="CASCADE"), nullable=False)


class User(Base):
    __tablename__ = "user"

    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(50), unique=True, nullable=False)
    password_hash = Column(String(128), nullable=False)
    role = Column(String(20), default="user")
    created_at = Column(DateTime, server_default=func.now())


class Crop(Base):
    __tablename__ = "crop"

    id = Column(Integer, primary_key=True, autoincrement=True)
    crop_name = Column(String(100), nullable=False)
    variety = Column(String(100), default="")
    plant_date = Column(DateTime, nullable=False)
    growth_stage = Column(String(30), default="seedling")
    zone_id = Column(Integer, ForeignKey("zone.id"), nullable=True)
    target_temperature = Column(Float, default=25.0)
    target_humidity = Column(Float, default=60.0)
    target_soil_moisture = Column(Float, default=50.0)
    target_light = Column(Float, default=30000.0)
    notes = Column(String(500), default="")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


class DailyReport(Base):
    __tablename__ = "daily_report"

    id = Column(Integer, primary_key=True, autoincrement=True)
    report_date = Column(String(10), nullable=False, unique=True)
    avg_temperature = Column(Float, default=0)
    avg_humidity = Column(Float, default=0)
    avg_light = Column(Float, default=0)
    avg_co2 = Column(Float, default=0)
    avg_soil_moisture = Column(Float, default=0)
    alert_count = Column(Integer, default=0)
    irrigation_count = Column(Integer, default=0)
    water_usage = Column(Float, default=0)
    summary = Column(Text, default="")
    created_at = Column(DateTime, server_default=func.now())


class WaterUsage(Base):
    __tablename__ = "water_usage"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(Integer, ForeignKey("device.id"), nullable=False)
    usage_liters = Column(Float, nullable=False)
    duration_seconds = Column(Integer, default=0)
    usage_date = Column(String(10), nullable=False)
    created_at = Column(DateTime, server_default=func.now())
