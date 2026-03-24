from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel


# --- Sensor ---
class SensorDataResponse(BaseModel):
    id: int
    temperature: float
    humidity: float
    light_intensity: float
    co2_level: float
    soil_moisture: float
    created_at: datetime

    class Config:
        from_attributes = True


class SensorHistoryResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[SensorDataResponse]


# --- Device ---
class DeviceResponse(BaseModel):
    id: int
    device_name: str
    device_type: str
    status: int
    params: Optional[dict] = {}
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class DeviceControlRequest(BaseModel):
    status: int  # 0 or 1


class DeviceParamsRequest(BaseModel):
    params: dict


# --- Alert Rule ---
class AlertRuleCreate(BaseModel):
    metric_name: str
    min_value: float
    max_value: float
    is_enabled: int = 1


class AlertRuleUpdate(BaseModel):
    metric_name: Optional[str] = None
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    is_enabled: Optional[int] = None


class AlertRuleResponse(BaseModel):
    id: int
    metric_name: str
    min_value: float
    max_value: float
    is_enabled: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# --- Alert Log ---
class AlertLogResponse(BaseModel):
    id: int
    rule_id: int
    metric_name: str
    metric_value: float
    alert_type: str
    is_read: int
    created_at: datetime

    class Config:
        from_attributes = True


class AlertLogListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[AlertLogResponse]


# --- Automation Rule ---
class AutomationRuleCreate(BaseModel):
    trigger_metric: str
    trigger_condition: str  # gt/lt/eq
    trigger_value: float
    action_device_id: int
    action_type: str  # on/off/set
    action_params: Optional[dict] = {}
    is_enabled: int = 1


class AutomationRuleUpdate(BaseModel):
    trigger_metric: Optional[str] = None
    trigger_condition: Optional[str] = None
    trigger_value: Optional[float] = None
    action_device_id: Optional[int] = None
    action_type: Optional[str] = None
    action_params: Optional[dict] = None
    is_enabled: Optional[int] = None


class AutomationRuleResponse(BaseModel):
    id: int
    trigger_metric: str
    trigger_condition: str
    trigger_value: float
    action_device_id: int
    action_type: str
    action_params: Optional[dict] = {}
    is_enabled: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# --- Device Log ---
class DeviceLogResponse(BaseModel):
    id: int
    device_id: int
    action: str
    params: Optional[dict] = {}
    source: str
    created_at: datetime

    class Config:
        from_attributes = True


class DeviceLogListResponse(BaseModel):
    total: int
    page: int
    page_size: int
    items: list[DeviceLogResponse]


# --- System ---
class SystemOverviewResponse(BaseModel):
    device_total: int
    device_online: int
    alert_today: int
    latest_sensor: Optional[SensorDataResponse] = None


# --- Scheduled Task ---
class ScheduledTaskCreate(BaseModel):
    task_name: str
    device_id: int
    action_type: str
    action_params: Optional[dict] = {}
    cron_expr: str
    repeat_type: str = "once"
    is_enabled: int = 1


class ScheduledTaskUpdate(BaseModel):
    task_name: Optional[str] = None
    device_id: Optional[int] = None
    action_type: Optional[str] = None
    action_params: Optional[dict] = None
    cron_expr: Optional[str] = None
    repeat_type: Optional[str] = None
    is_enabled: Optional[int] = None


class ScheduledTaskResponse(BaseModel):
    id: int
    task_name: str
    device_id: int
    action_type: str
    action_params: Optional[dict] = {}
    cron_expr: str
    repeat_type: str
    is_enabled: int
    next_run: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# --- Zone ---
class ZoneCreate(BaseModel):
    zone_name: str
    zone_type: str = "greenhouse"
    description: str = ""
    is_active: int = 1


class ZoneResponse(BaseModel):
    id: int
    zone_name: str
    zone_type: str
    description: str
    device_count: int = 0
    is_active: int
    created_at: datetime

    class Config:
        from_attributes = True


# --- Stats ---
class MetricStatsResponse(BaseModel):
    metric_name: str
    avg_value: float
    min_value: float
    max_value: float
    latest_value: float


class StatsResponse(BaseModel):
    date: str
    metrics: list[MetricStatsResponse]


# --- User / Auth ---
class UserRegister(BaseModel):
    username: str
    password: str
    captcha_id: str
    captcha_code: str


class UserLogin(BaseModel):
    username: str
    password: str


class CaptchaResponse(BaseModel):
    captcha_id: str
    captcha_text: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    username: str
    role: str


class UserResponse(BaseModel):
    id: int
    username: str
    role: str
    created_at: datetime

    class Config:
        from_attributes = True


# --- Crop ---
class CropCreate(BaseModel):
    crop_name: str
    variety: str = ""
    plant_date: datetime
    growth_stage: str = "seedling"
    zone_id: Optional[int] = None
    target_temperature: float = 25.0
    target_humidity: float = 60.0
    target_soil_moisture: float = 50.0
    target_light: float = 30000.0
    notes: str = ""


class CropUpdate(BaseModel):
    crop_name: Optional[str] = None
    variety: Optional[str] = None
    growth_stage: Optional[str] = None
    zone_id: Optional[int] = None
    target_temperature: Optional[float] = None
    target_humidity: Optional[float] = None
    target_soil_moisture: Optional[float] = None
    target_light: Optional[float] = None
    notes: Optional[str] = None


class CropResponse(BaseModel):
    id: int
    crop_name: str
    variety: str
    plant_date: datetime
    growth_stage: str
    zone_id: Optional[int] = None
    target_temperature: float
    target_humidity: float
    target_soil_moisture: float
    target_light: float
    notes: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# --- Daily Report ---
class DailyReportResponse(BaseModel):
    id: int
    report_date: str
    avg_temperature: float
    avg_humidity: float
    avg_light: float
    avg_co2: float
    avg_soil_moisture: float
    alert_count: int
    irrigation_count: int
    water_usage: float
    summary: str
    created_at: datetime

    class Config:
        from_attributes = True


# --- Water Usage ---
class WaterUsageResponse(BaseModel):
    id: int
    device_id: int
    usage_liters: float
    duration_seconds: int
    usage_date: str
    created_at: datetime

    class Config:
        from_attributes = True


class WaterDailySummary(BaseModel):
    date: str
    total_liters: float
    total_seconds: int


# --- Alert Stats ---
class AlertStatsItem(BaseModel):
    metric_name: str
    high_count: int
    low_count: int
    total: int


class AlertStatsResponse(BaseModel):
    period: str
    items: list[AlertStatsItem]


# --- Batch Device Control ---
class BatchControlRequest(BaseModel):
    device_ids: list[int]
    status: int


# --- Device Health ---
class DeviceHealthResponse(BaseModel):
    device_id: int
    device_name: str
    device_type: str
    uptime_hours: float
    offline_count: int
    error_count: int
    health_score: int
    status: int


# --- Weather ---
class WeatherResponse(BaseModel):
    city: str
    temperature: float
    humidity: float
    weather: str
    wind: str
    suggestion: str


# --- WebSocket ---
class WebSocketMessage(BaseModel):
    type: str  # sensor_data / alert / device_status
    data: Any
