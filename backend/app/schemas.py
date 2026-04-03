from datetime import datetime
from typing import Optional, Any
from pydantic import BaseModel, Field


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
    params: Optional[dict] = Field(default_factory=dict)
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
    action_params: Optional[dict] = Field(default_factory=dict)
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
    action_params: Optional[dict] = Field(default_factory=dict)
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
    params: Optional[dict] = Field(default_factory=dict)
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
    action_params: Optional[dict] = Field(default_factory=dict)
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
    action_params: Optional[dict] = Field(default_factory=dict)
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
    captcha_image: str
    captcha_text: str = ""


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


# --- AI / Edge ---
class WeatherForecastPoint(BaseModel):
    time: str
    weather: str
    temperature: float
    humidity: float


class WeatherForecastResponse(BaseModel):
    horizon_hours: int
    points: list[WeatherForecastPoint]
    suggestions: list[str]


class PestDetectResponse(BaseModel):
    risk_level: str
    confidence: float
    pest_type: str
    reason: str
    engine: str = "heuristic_v2"
    quality_score: float = 0.0
    metrics: dict[str, float] = Field(default_factory=dict)
    suggestions: list[str] = Field(default_factory=list)


class MobilePestTriggerRequest(BaseModel):
    camera_id: str = "camera-1"
    zone_id: str = "zone-1"
    risk_hint: str = "auto"  # auto/high/medium/low


class PestDetectFromPathRequest(BaseModel):
    image_url: str
    camera_id: str = "camera-1"
    zone_id: str = "zone-1"
    source: str = "mobile"
    risk_hint_fallback: str = "auto"


class PestRealtimeItem(BaseModel):
    created_at: str
    source: str
    camera_id: str = ""
    zone_id: str = ""
    risk_level: str
    confidence: float
    pest_type: str
    engine: str
    quality_score: float
    reason: str


class PestFinalSummaryResponse(BaseModel):
    window_minutes: int
    source: str
    window_start: str = ""
    window_end: str = ""
    total: int
    risk_counts: dict[str, int]
    avg_confidence: float
    avg_quality: float
    risk_index: float = 0.0
    high_risk_ratio: float = 0.0
    trend: str = "stable"
    source_breakdown: dict[str, int] = Field(default_factory=dict)
    top_pest_type: str
    latest: Optional[PestRealtimeItem] = None


class PestRealtimeListResponse(BaseModel):
    total: int
    source: str = "all"
    since_minutes: int = 0
    risk_levels: list[str] = Field(default_factory=list)
    items: list[PestRealtimeItem]


class EdgeNetworkRequest(BaseModel):
    online: bool


class EdgeControlRequest(BaseModel):
    task_id: str
    action: str
    payload: dict = Field(default_factory=dict)


class EdgeTaskItem(BaseModel):
    task_id: str
    action: str
    payload: dict
    retry_count: int = 0
    created_at: str


class EdgeStatusResponse(BaseModel):
    online: bool
    queued_count: int
    dead_letter_count: int = 0
    max_retries: int = 3
    queue: list[EdgeTaskItem]


class EdgeHistoryItem(BaseModel):
    event_type: str
    detail: dict
    created_at: str


class EdgeHistoryResponse(BaseModel):
    total: int
    items: list[EdgeHistoryItem]


class EdgeDeadLetterItem(BaseModel):
    task_id: str
    action: str
    payload: dict
    reason: str
    retry_count: int
    failed_at: str


class EdgeDeadLetterResponse(BaseModel):
    total: int
    items: list[EdgeDeadLetterItem]


class AIOpsAuditItem(BaseModel):
    created_at: str
    actor: str
    role: str
    action: str
    result: str
    ip: str
    detail: dict


class AIOpsAuditResponse(BaseModel):
    total: int
    items: list[AIOpsAuditItem]


class AuthzPolicyResponse(BaseModel):
    updated_at: str
    permissions: dict[str, list[str]]


class AuthzPolicyUpdateRequest(BaseModel):
    permissions: dict[str, list[str]]


class AuthzPolicyTemplatesResponse(BaseModel):
    current: dict[str, list[str]]
    templates: dict[str, dict[str, list[str]]]


class AuthzApplyTemplateRequest(BaseModel):
    template_name: str


class MicroClimateZoneInput(BaseModel):
    zone_id: int
    zone_name: str
    temperature: float
    humidity: float
    soil_moisture: float
    target_temperature: float
    target_humidity: float
    target_soil_moisture: float


class MicroClimateOptimizeRequest(BaseModel):
    zones: list[MicroClimateZoneInput]


class MicroClimateAction(BaseModel):
    zone_id: int
    zone_name: str
    actions: list[str]
    risk_score: float = 0.0


class MicroClimateOptimizeResponse(BaseModel):
    generated_at: str
    actions: list[MicroClimateAction]


class StrategyExecuteRequest(BaseModel):
    actions: list[MicroClimateAction]
    source: str = "ai_ops_web"


class StrategyExecuteResult(BaseModel):
    zone_id: int
    zone_name: str
    submitted: list[dict] = Field(default_factory=list)


class StrategyExecuteResponse(BaseModel):
    generated_at: str
    source: str
    results: list[StrategyExecuteResult]


class IncidentPlanRequest(BaseModel):
    scenario: str
    risk_level: str = "medium"
    pest_type: str = ""
    zone_id: Optional[int] = None
    zone_name: str = "default_zone"
    auto_enqueue: bool = False


class IncidentPlanStep(BaseModel):
    order: int
    title: str
    detail: str


class IncidentPlanResponse(BaseModel):
    generated_at: str
    scenario: str
    risk_level: str
    steps: list[IncidentPlanStep]
    enqueued_tasks: list[dict] = Field(default_factory=list)


class WeatherPredictRequest(BaseModel):
    city: str = "Beijing"
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    horizon_hours: int = 24


class WeatherPredictResponse(BaseModel):
    city: str
    latitude: float
    longitude: float
    horizon_hours: int
    points: list[WeatherForecastPoint]
    suggestions: list[str]


class HuaweiWatchSyncRequest(BaseModel):
    watch_id: str = "watch-default"
    heart_rate: float = 80.0
    steps: int = 0
    skin_temperature: float = 36.5
    battery: int = 80
    signal_strength: int = 3
    zone_id: str = ""


class HuaweiWatchSyncResponse(BaseModel):
    accepted: bool
    tips: list[str]
    risk_flags: list[str] = Field(default_factory=list)
    sample: dict


class XiaoYiCommandRequest(BaseModel):
    intent: str
    text: str = ""
    params: dict = Field(default_factory=dict)


class XiaoYiCommandResponse(BaseModel):
    accepted: bool
    command: dict
    dispatched: list[dict] = Field(default_factory=list)


class OpenHarmonyHandoffRequest(BaseModel):
    handoff_id: str = ""
    source_device: str
    target_device: str
    method: str = "nfc"  # nfc/distributed_bus
    ttl_seconds: int = 180
    payload: dict = Field(default_factory=dict)


class OpenHarmonyHandoffResponse(BaseModel):
    accepted: bool
    handoff: dict


class IntegrationRecordsResponse(BaseModel):
    total: int
    items: list[dict]


class OpenClawAutofixRequest(BaseModel):
    incident_type: str
    context: dict = Field(default_factory=dict)
    dry_run: bool = False


class OpenClawAutofixResponse(BaseModel):
    source: str
    incident_type: str
    dry_run: bool
    actions: list[dict]
    submitted: list[dict]
