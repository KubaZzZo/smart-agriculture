// 智慧农业控制系统 - 常量定义

export class ApiConstants {
  static readonly BASE_URL: string = 'http://10.101.113.171:8000';
  static readonly WS_URL: string = 'ws://10.101.113.171:8000/ws/realtime';

  // API 路径
  static readonly AUTH_LOGIN: string = '/api/auth/login';
  static readonly AUTH_REGISTER: string = '/api/auth/register';
  static readonly AUTH_CAPTCHA: string = '/api/auth/captcha';
  static readonly SENSOR_LATEST: string = '/api/sensor/realtime';
  static readonly SENSOR_HISTORY: string = '/api/sensor/history';
  static readonly SENSOR_STATS: string = '/api/sensor/stats';
  static readonly DEVICE_LIST: string = '/api/device/list';
  static readonly DEVICE_CONTROL: string = '/api/device'; // /{id}/control
  static readonly DEVICE_PARAMS: string = '/api/device'; // /{id}/params
  static readonly DEVICE_LOG: string = '/api/device/log';
  static readonly ALERT_RULES: string = '/api/alert/rules';
  static readonly ALERT_LOGS: string = '/api/alert/logs';
  static readonly AUTOMATION_LIST: string = '/api/automation/rules';
  static readonly SYSTEM_OVERVIEW: string = '/api/system/overview';
  static readonly SCHEDULE_LIST: string = '/api/schedule/tasks';
  static readonly ZONE_LIST: string = '/api/zone';
  static readonly CROP_LIST: string = '/api/crop';
  static readonly REPORT_LIST: string = '/api/report';
  static readonly REPORT_DAILY: string = '/api/report/daily';
  static readonly WATER_STATS: string = '/api/water/stats';
  static readonly WATER_TODAY: string = '/api/water/today';
  static readonly WEATHER_CURRENT: string = '/api/weather';
  static readonly CAMERA_SNAPSHOT: string = '/api/camera/snapshot';
}

// 颜色主题 - 农业绿色系
export class AppColors {
  static readonly PRIMARY: string = '#2E7D32';
  static readonly PRIMARY_LIGHT: string = '#4CAF50';
  static readonly PRIMARY_DARK: string = '#1B5E20';
  static readonly ACCENT: string = '#FF9800';
  static readonly WARN: string = '#F44336';
  static readonly WARN_LIGHT: string = '#FFEBEE';
  static readonly BG: string = '#F5F5F5';
  static readonly CARD_BG: string = '#FFFFFF';
  static readonly TEXT_PRIMARY: string = '#212121';
  static readonly TEXT_SECONDARY: string = '#757575';
  static readonly TEXT_HINT: string = '#BDBDBD';
  static readonly DIVIDER: string = '#E0E0E0';
  static readonly TEMP_COLOR: string = '#F44336';
  static readonly HUMIDITY_COLOR: string = '#2196F3';
  static readonly LIGHT_COLOR: string = '#FF8F00';
  static readonly CO2_COLOR: string = '#9C27B0';
  static readonly SOIL_COLOR: string = '#795548';
}

// 指标名称映射
export class MetricNames {
  static readonly MAP: Record<string, string> = {
    'temperature': '温度',
    'humidity': '湿度',
    'light_intensity': '光照强度',
    'co2_level': 'CO₂浓度',
    'soil_moisture': '土壤湿度'
  };

  static readonly UNITS: Record<string, string> = {
    'temperature': '°C',
    'humidity': '%',
    'light_intensity': 'Lux',
    'co2_level': 'ppm',
    'soil_moisture': '%'
  };
}

// 设备类型映射
export class DeviceTypes {
  static readonly MAP: Record<string, string> = {
    'valve': '水阀',
    'pump': '水泵',
    'led': 'LED补光灯',
    'camera': '摄像头',
    'fan': '通风风扇'
  };

  static readonly ICONS: Record<string, Resource> = {};
}
