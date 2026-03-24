CREATE DATABASE IF NOT EXISTS smart_agriculture DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE smart_agriculture;

-- 传感器数据表
CREATE TABLE IF NOT EXISTS sensor_data (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    temperature FLOAT NOT NULL,
    humidity FLOAT NOT NULL,
    light_intensity FLOAT NOT NULL,
    co2_level FLOAT NOT NULL,
    soil_moisture FLOAT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 设备状态表
CREATE TABLE IF NOT EXISTS device (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_name VARCHAR(100) NOT NULL,
    device_type VARCHAR(50) NOT NULL,
    status TINYINT DEFAULT 0,
    params JSON,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 预警规则表
CREATE TABLE IF NOT EXISTS alert_rule (
    id INT PRIMARY KEY AUTO_INCREMENT,
    metric_name VARCHAR(30) NOT NULL,
    min_value FLOAT NOT NULL,
    max_value FLOAT NOT NULL,
    is_enabled TINYINT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 预警记录表
CREATE TABLE IF NOT EXISTS alert_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    rule_id INT NOT NULL,
    metric_name VARCHAR(30) NOT NULL,
    metric_value FLOAT NOT NULL,
    alert_type VARCHAR(10) NOT NULL,
    is_read TINYINT DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (rule_id) REFERENCES alert_rule(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 联动规则表
CREATE TABLE IF NOT EXISTS automation_rule (
    id INT PRIMARY KEY AUTO_INCREMENT,
    trigger_metric VARCHAR(30) NOT NULL,
    trigger_condition VARCHAR(10) NOT NULL,
    trigger_value FLOAT NOT NULL,
    action_device_id INT NOT NULL,
    action_type VARCHAR(10) NOT NULL,
    action_params JSON,
    is_enabled TINYINT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (action_device_id) REFERENCES device(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 设备操作记录表
CREATE TABLE IF NOT EXISTS device_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    device_id INT NOT NULL,
    action VARCHAR(20) NOT NULL,
    params JSON,
    source VARCHAR(20) NOT NULL DEFAULT 'manual',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES device(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 定时任务表
CREATE TABLE IF NOT EXISTS scheduled_task (
    id INT PRIMARY KEY AUTO_INCREMENT,
    task_name VARCHAR(100) NOT NULL,
    device_id INT NOT NULL,
    action_type VARCHAR(10) NOT NULL,
    action_params JSON,
    cron_expr VARCHAR(50) NOT NULL,
    repeat_type VARCHAR(20) NOT NULL DEFAULT 'once',
    is_enabled TINYINT DEFAULT 1,
    next_run DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES device(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 区域/大棚表
CREATE TABLE IF NOT EXISTS zone (
    id INT PRIMARY KEY AUTO_INCREMENT,
    zone_name VARCHAR(100) NOT NULL,
    zone_type VARCHAR(30) NOT NULL DEFAULT 'greenhouse',
    description VARCHAR(255) DEFAULT '',
    is_active TINYINT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 区域-设备关联表
CREATE TABLE IF NOT EXISTS zone_device (
    id INT PRIMARY KEY AUTO_INCREMENT,
    zone_id INT NOT NULL,
    device_id INT NOT NULL,
    FOREIGN KEY (zone_id) REFERENCES zone(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES device(id) ON DELETE CASCADE,
    UNIQUE KEY uk_zone_device (zone_id, device_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用户表
CREATE TABLE IF NOT EXISTS user (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(128) NOT NULL,
    role VARCHAR(20) DEFAULT 'user',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 作物管理表
CREATE TABLE IF NOT EXISTS crop (
    id INT PRIMARY KEY AUTO_INCREMENT,
    crop_name VARCHAR(100) NOT NULL,
    variety VARCHAR(100) DEFAULT '',
    plant_date DATETIME NOT NULL,
    growth_stage VARCHAR(30) DEFAULT 'seedling',
    zone_id INT,
    target_temperature FLOAT DEFAULT 25.0,
    target_humidity FLOAT DEFAULT 60.0,
    target_soil_moisture FLOAT DEFAULT 50.0,
    target_light FLOAT DEFAULT 30000.0,
    notes VARCHAR(500) DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (zone_id) REFERENCES zone(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 每日报告表
CREATE TABLE IF NOT EXISTS daily_report (
    id INT PRIMARY KEY AUTO_INCREMENT,
    report_date VARCHAR(10) NOT NULL UNIQUE,
    avg_temperature FLOAT DEFAULT 0,
    avg_humidity FLOAT DEFAULT 0,
    avg_light FLOAT DEFAULT 0,
    avg_co2 FLOAT DEFAULT 0,
    avg_soil_moisture FLOAT DEFAULT 0,
    alert_count INT DEFAULT 0,
    irrigation_count INT DEFAULT 0,
    water_usage FLOAT DEFAULT 0,
    summary TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 用水量记录表
CREATE TABLE IF NOT EXISTS water_usage (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    device_id INT NOT NULL,
    usage_liters FLOAT NOT NULL,
    duration_seconds INT DEFAULT 0,
    usage_date VARCHAR(10) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES device(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 初始设备数据
INSERT INTO device (device_name, device_type, status, params) VALUES
('水阀', 'valve', 0, '{"flow_rate": 0}'),
('水泵', 'pump', 0, '{"flow_rate": 0}'),
('LED补光灯', 'led', 0, '{"brightness": 0}'),
('监控摄像头', 'camera', 1, '{}'),
('通风风扇', 'fan', 0, '{"speed": 0}');

-- 默认预警规则
INSERT INTO alert_rule (metric_name, min_value, max_value, is_enabled) VALUES
('temperature', 15, 35, 1),
('humidity', 40, 80, 1),
('light_intensity', 2000, 80000, 1),
('co2_level', 400, 1500, 1),
('soil_moisture', 20, 70, 1);

-- 默认联动规则
INSERT INTO automation_rule (trigger_metric, trigger_condition, trigger_value, action_device_id, action_type, action_params, is_enabled) VALUES
('soil_moisture', 'lt', 30, 2, 'on', '{}', 1),
('soil_moisture', 'gt', 70, 2, 'off', '{}', 1),
('light_intensity', 'lt', 5000, 3, 'on', '{"brightness": 80}', 1),
('co2_level', 'gt', 1000, 5, 'on', '{"speed": 100}', 1),
('co2_level', 'lt', 600, 5, 'off', '{}', 1);

-- 默认区域
INSERT INTO zone (zone_name, zone_type, description) VALUES
('1号温室大棚', 'greenhouse', '主要种植区'),
('露天试验田', 'field', '露天种植试验区');
