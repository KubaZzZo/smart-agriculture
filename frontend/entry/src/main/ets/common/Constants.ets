export class FrontendDeploy {
  static readonly DEFAULT_ENV: string = 'dev';

  // Update these three endpoints for your deployment.
  static readonly DEV_API_BASE_URL: string = 'http://10.101.113.171:8000';
  static readonly DEV_WS_BASE_URL: string = 'ws://10.101.113.171:8000';

  static readonly STAGING_API_BASE_URL: string = 'https://staging.example.com';
  static readonly STAGING_WS_BASE_URL: string = 'wss://staging.example.com';

  static readonly PROD_API_BASE_URL: string = 'https://api.example.com';
  static readonly PROD_WS_BASE_URL: string = 'wss://api.example.com';
}

export class AppConfig {
  static readonly ENV_DEV: string = 'dev';
  static readonly ENV_STAGING: string = 'staging';
  static readonly ENV_PROD: string = 'prod';

  static readonly DEFAULT_ENV: string = FrontendDeploy.DEFAULT_ENV;
  static readonly ENABLE_OFFLINE_MOCK: boolean = AppConfig.env() === AppConfig.ENV_DEV;

  static env(): string {
    const value: string = (AppStorage.get<string>('APP_ENV') || AppConfig.DEFAULT_ENV).toLowerCase();
    if (value === AppConfig.ENV_STAGING || value === AppConfig.ENV_PROD || value === AppConfig.ENV_DEV) {
      return value;
    }
    return AppConfig.DEFAULT_ENV;
  }

  static apiBaseUrl(): string {
    const overrideUrl: string = AppStorage.get<string>('API_BASE_URL') || '';
    if (overrideUrl) {
      return overrideUrl;
    }
    const env: string = AppConfig.env();
    if (env === AppConfig.ENV_STAGING) {
      return FrontendDeploy.STAGING_API_BASE_URL;
    }
    if (env === AppConfig.ENV_PROD) {
      return FrontendDeploy.PROD_API_BASE_URL;
    }
    return FrontendDeploy.DEV_API_BASE_URL;
  }

  static wsBaseUrl(): string {
    const overrideUrl: string = AppStorage.get<string>('WS_BASE_URL') || '';
    if (overrideUrl) {
      return overrideUrl;
    }
    const env: string = AppConfig.env();
    if (env === AppConfig.ENV_STAGING) {
      return FrontendDeploy.STAGING_WS_BASE_URL;
    }
    if (env === AppConfig.ENV_PROD) {
      return FrontendDeploy.PROD_WS_BASE_URL;
    }
    return FrontendDeploy.DEV_WS_BASE_URL;
  }
}

export class ApiConstants {
  static readonly BASE_URL: string = AppConfig.apiBaseUrl();
  static readonly WS_URL: string = `${AppConfig.wsBaseUrl()}/ws/realtime`;

  static readonly AUTH_LOGIN: string = '/api/auth/login';
  static readonly AUTH_REGISTER: string = '/api/auth/register';
  static readonly AUTH_CAPTCHA: string = '/api/auth/captcha';
  static readonly SENSOR_LATEST: string = '/api/sensor/realtime';
  static readonly SENSOR_HISTORY: string = '/api/sensor/history';
  static readonly SENSOR_STATS: string = '/api/sensor/stats';
  static readonly DEVICE_LIST: string = '/api/device/list';
  static readonly DEVICE_CONTROL: string = '/api/device';
  static readonly DEVICE_PARAMS: string = '/api/device';
  static readonly DEVICE_LOG: string = '/api/device';
  static readonly ALERT_RULES: string = '/api/alert/rules';
  static readonly ALERT_LOGS: string = '/api/alert/logs';
  static readonly AUTOMATION_LIST: string = '/api/automation/rules';
  static readonly SYSTEM_OVERVIEW: string = '/api/system/overview';
  static readonly SCHEDULE_LIST: string = '/api/schedule/tasks';
  static readonly ZONE_LIST: string = '/api/zone';
  static readonly CROP_LIST: string = '/api/crop';
  static readonly REPORT_LIST: string = '/api/report';
  static readonly REPORT_DAILY: string = '/api/report/generate';
  static readonly WATER_STATS: string = '/api/water/daily';
  static readonly WATER_TODAY: string = '/api/water/today';
  static readonly WEATHER_CURRENT: string = '/api/weather';
  static readonly CAMERA_SNAPSHOT: string = '/api/camera/snapshot';
  static readonly AI_PEST_LATEST: string = '/api/ai/vision/pest/latest';
  static readonly AI_PEST_RECENT: string = '/api/ai/vision/pest/recent';
  static readonly AI_PEST_FINAL_SUMMARY: string = '/api/ai/vision/pest/final-summary';
  static readonly AI_PEST_MOBILE_TRIGGER: string = '/api/ai/vision/pest-detect/mobile';
  static readonly AI_PEST_DETECT_FROM_PATH: string = '/api/ai/vision/pest-detect/from-path';
}

export class AppColors {
  static readonly PRIMARY: string = '#1E8A5A';
  static readonly PRIMARY_LIGHT: string = '#39AD74';
  static readonly PRIMARY_DARK: string = '#0E4F35';
  static readonly ACCENT: string = '#A35A2A';
  static readonly WARN: string = '#CF3D3D';
  static readonly WARN_LIGHT: string = '#FDEDED';
  static readonly BG: string = '#EEF4F0';
  static readonly CARD_BG: string = '#FFFFFF';
  static readonly TEXT_PRIMARY: string = '#1A2B22';
  static readonly TEXT_SECONDARY: string = '#53695E';
  static readonly TEXT_HINT: string = '#8FA096';
  static readonly DIVIDER: string = '#DEE8E1';
  static readonly TEMP_COLOR: string = '#DE5A4A';
  static readonly HUMIDITY_COLOR: string = '#2A7FB8';
  static readonly LIGHT_COLOR: string = '#8A4F00';
  static readonly CO2_COLOR: string = '#3E6F88';
  static readonly SOIL_COLOR: string = '#846749';
}

export class MetricNames {
  static readonly MAP: Record<string, string> = {
    'temperature': '温度',
    'humidity': '湿度',
    'light_intensity': '光照强度',
    'co2_level': '二氧化碳',
    'soil_moisture': '土壤湿度',
  };

  static readonly UNITS: Record<string, string> = {
    'temperature': '℃',
    'humidity': '%',
    'light_intensity': '勒克斯',
    'co2_level': '百万分率',
    'soil_moisture': '%',
  };
}

export class DeviceTypes {
  static readonly MAP: Record<string, string> = {
    'valve': '水阀',
    'pump': '水泵',
    'led': '补光灯',
    'camera': '摄像头',
    'fan': '风机',
  };

  static readonly ICONS: Record<string, Resource> = {};
}
