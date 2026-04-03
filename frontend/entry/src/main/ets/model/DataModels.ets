// 智慧农业控制系统 - 数据模型定义

export interface SensorData {
  id: number;
  temperature: number;
  humidity: number;
  light_intensity: number;
  co2_level: number;
  soil_moisture: number;
  created_at: string;
}

export interface SensorHistoryResponse {
  total: number;
  page: number;
  page_size: number;
  items: SensorData[];
}

export interface DeviceInfo {
  id: number;
  device_name: string;
  device_type: string;
  status: number;
  params: Record<string, number>;
  created_at: string;
  updated_at: string;
}

export interface AlertRule {
  id: number;
  metric_name: string;
  min_value: number;
  max_value: number;
  is_enabled: number;
  created_at: string;
  updated_at: string;
}

export interface AlertLog {
  id: number;
  rule_id: number;
  metric_name: string;
  metric_value: number;
  alert_type: string;
  is_read: number;
  created_at: string;
}

export interface AlertLogListResponse {
  total: number;
  page: number;
  page_size: number;
  items: AlertLog[];
}

export interface AutomationRule {
  id: number;
  trigger_metric: string;
  trigger_condition: string;
  trigger_value: number;
  action_device_id: number;
  action_type: string;
  action_params: Record<string, number>;
  is_enabled: number;
  created_at: string;
  updated_at: string;
}

export interface DeviceLog {
  id: number;
  device_id: number;
  action: string;
  params: Record<string, number>;
  source: string;
  created_at: string;
}

export interface DeviceLogListResponse {
  total: number;
  page: number;
  page_size: number;
  items: DeviceLog[];
}

export interface SystemOverview {
  device_total: number;
  device_online: number;
  alert_today: number;
  latest_sensor: SensorData | null;
}

export interface ScheduledTask {
  id: number;
  task_name: string;
  device_id: number;
  action_type: string;
  action_params: Record<string, number>;
  cron_expr: string;
  repeat_type: string;
  is_enabled: number;
  next_run: string | null;
  created_at: string;
  updated_at: string;
}

export interface ZoneInfo {
  id: number;
  zone_name: string;
  zone_type: string;
  description: string;
  device_count: number;
  is_active: number;
  created_at: string;
}

export interface CropInfo {
  id: number;
  crop_name: string;
  variety: string;
  plant_date: string;
  growth_stage: string;
  zone_id: number | null;
  target_temperature: number;
  target_humidity: number;
  target_soil_moisture: number;
  target_light: number;
  notes: string;
  created_at: string;
  updated_at: string;
}

export interface DailyReport {
  id: number;
  report_date: string;
  avg_temperature: number;
  avg_humidity: number;
  avg_light: number;
  avg_co2: number;
  avg_soil_moisture: number;
  alert_count: number;
  irrigation_count: number;
  water_usage: number;
  summary: string;
  created_at: string;
}

export interface WeatherInfo {
  temperature: number;
  humidity: number;
  description: string;
  wind_speed: number;
}

export interface PestRealtimeItem {
  created_at: string;
  source: string;
  camera_id: string;
  zone_id: string;
  risk_level: string;
  confidence: number;
  pest_type: string;
  engine: string;
  quality_score: number;
  reason: string;
}

export interface PestFinalSummary {
  window_minutes: number;
  source: string;
  total: number;
  risk_counts: Record<string, number>;
  avg_confidence: number;
  avg_quality: number;
  top_pest_type: string;
  latest: PestRealtimeItem | null;
}

export interface PestRealtimeListResponse {
  total: number;
  items: PestRealtimeItem[];
}

export interface MobilePestTriggerRequest {
  camera_id: string;
  zone_id: string;
  risk_hint: string;
}

export interface CameraSnapshotResponse {
  image_url: string;
  timestamp: string;
}

export interface PestDetectFromPathRequest {
  image_url: string;
  camera_id: string;
  zone_id: string;
  source: string;
  risk_hint_fallback: string;
}

export interface TokenResponse {
  access_token: string;
  token_type: string;
  username: string;
  role: string;
}

export interface ApiResponse<T> {
  code: number;
  data: T;
  message: string;
}

// ArkTS 请求体接口定义
export interface ControlRequest {
  status: number;
}

export interface DeviceParamsUpdateRequest {
  params: Record<string, number>;
}

export interface AlertRuleUpdateRequest {
  is_enabled: number;
}

export interface AutomationCreateRequest {
  trigger_metric: string;
  trigger_condition: string;
  trigger_value: number;
  action_device_id: number;
  action_type: string;
  action_params: Record<string, number>;
  is_enabled: number;
}

export interface AutomationUpdateRequest {
  is_enabled: number;
}

export interface ZoneCreateRequest {
  zone_name: string;
  zone_type: string;
  description: string;
}

export interface CropCreateRequest {
  crop_name: string;
  variety: string;
  plant_date: string;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface RegisterRequest {
  username: string;
  password: string;
  captcha_id: string;
  captcha_code: string;
}

export interface CaptchaResponse {
  captcha_id: string;
  captcha_image: string;
  captcha_text?: string;
}

export interface WaterTodayResponse {
  date: string;
  total_liters: number;
}
