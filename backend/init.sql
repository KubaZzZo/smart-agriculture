CREATE DATABASE IF NOT EXISTS smart_agriculture
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE smart_agriculture;

CREATE TABLE IF NOT EXISTS sensor_data (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    temperature FLOAT NOT NULL,
    humidity FLOAT NOT NULL,
    light_intensity FLOAT NOT NULL,
    co2_level FLOAT NOT NULL,
    soil_moisture FLOAT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS device (
    id INT PRIMARY KEY AUTO_INCREMENT,
    device_name VARCHAR(100) NOT NULL,
    device_type VARCHAR(50) NOT NULL,
    status TINYINT DEFAULT 0,
    params JSON,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_device_type (device_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS alert_rule (
    id INT PRIMARY KEY AUTO_INCREMENT,
    metric_name VARCHAR(30) NOT NULL,
    min_value FLOAT NOT NULL,
    max_value FLOAT NOT NULL,
    is_enabled TINYINT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_alert_metric_name (metric_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

CREATE TABLE IF NOT EXISTS device_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    device_id INT NOT NULL,
    action VARCHAR(20) NOT NULL,
    params JSON,
    source VARCHAR(20) NOT NULL DEFAULT 'manual',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES device(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

CREATE TABLE IF NOT EXISTS zone (
    id INT PRIMARY KEY AUTO_INCREMENT,
    zone_name VARCHAR(100) NOT NULL,
    zone_type VARCHAR(30) NOT NULL DEFAULT 'greenhouse',
    description VARCHAR(255) DEFAULT '',
    is_active TINYINT DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_zone_name (zone_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS zone_device (
    id INT PRIMARY KEY AUTO_INCREMENT,
    zone_id INT NOT NULL,
    device_id INT NOT NULL,
    FOREIGN KEY (zone_id) REFERENCES zone(id) ON DELETE CASCADE,
    FOREIGN KEY (device_id) REFERENCES device(id) ON DELETE CASCADE,
    UNIQUE KEY uk_zone_device (zone_id, device_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(128) NOT NULL,
    role VARCHAR(20) DEFAULT 'user',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

CREATE TABLE IF NOT EXISTS water_usage (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    device_id INT NOT NULL,
    usage_liters FLOAT NOT NULL,
    duration_seconds INT DEFAULT 0,
    usage_date VARCHAR(10) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES device(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS auth_audit_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    event_type VARCHAR(30) NOT NULL,
    username VARCHAR(50) DEFAULT '',
    ip VARCHAR(64) DEFAULT '',
    status VARCHAR(20) DEFAULT 'ok',
    reason VARCHAR(255) DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO device (device_name, device_type, status, params)
SELECT 'Water Valve', 'valve', 0, '{"flow_rate": 0}'
WHERE NOT EXISTS (SELECT 1 FROM device WHERE device_type = 'valve');
INSERT INTO device (device_name, device_type, status, params)
SELECT 'Water Pump', 'pump', 0, '{"flow_rate": 0}'
WHERE NOT EXISTS (SELECT 1 FROM device WHERE device_type = 'pump');
INSERT INTO device (device_name, device_type, status, params)
SELECT 'LED Grow Light', 'led', 0, '{"brightness": 0}'
WHERE NOT EXISTS (SELECT 1 FROM device WHERE device_type = 'led');
INSERT INTO device (device_name, device_type, status, params)
SELECT 'Camera', 'camera', 1, '{}'
WHERE NOT EXISTS (SELECT 1 FROM device WHERE device_type = 'camera');
INSERT INTO device (device_name, device_type, status, params)
SELECT 'Ventilation Fan', 'fan', 0, '{"speed": 0}'
WHERE NOT EXISTS (SELECT 1 FROM device WHERE device_type = 'fan');

INSERT INTO alert_rule (metric_name, min_value, max_value, is_enabled)
SELECT 'temperature', 15, 35, 1
WHERE NOT EXISTS (SELECT 1 FROM alert_rule WHERE metric_name = 'temperature');
INSERT INTO alert_rule (metric_name, min_value, max_value, is_enabled)
SELECT 'humidity', 40, 80, 1
WHERE NOT EXISTS (SELECT 1 FROM alert_rule WHERE metric_name = 'humidity');
INSERT INTO alert_rule (metric_name, min_value, max_value, is_enabled)
SELECT 'light_intensity', 2000, 80000, 1
WHERE NOT EXISTS (SELECT 1 FROM alert_rule WHERE metric_name = 'light_intensity');
INSERT INTO alert_rule (metric_name, min_value, max_value, is_enabled)
SELECT 'co2_level', 400, 1500, 1
WHERE NOT EXISTS (SELECT 1 FROM alert_rule WHERE metric_name = 'co2_level');
INSERT INTO alert_rule (metric_name, min_value, max_value, is_enabled)
SELECT 'soil_moisture', 20, 70, 1
WHERE NOT EXISTS (SELECT 1 FROM alert_rule WHERE metric_name = 'soil_moisture');

INSERT INTO automation_rule (
    trigger_metric,
    trigger_condition,
    trigger_value,
    action_device_id,
    action_type,
    action_params,
    is_enabled
)
SELECT
    'soil_moisture',
    'lt',
    30,
    d.id,
    'on',
    '{}',
    1
FROM device d
WHERE d.device_type = 'pump'
  AND NOT EXISTS (
      SELECT 1
      FROM automation_rule a
      WHERE a.trigger_metric = 'soil_moisture'
        AND a.trigger_condition = 'lt'
        AND a.trigger_value = 30
        AND a.action_type = 'on'
  );

INSERT INTO automation_rule (
    trigger_metric,
    trigger_condition,
    trigger_value,
    action_device_id,
    action_type,
    action_params,
    is_enabled
)
SELECT
    'soil_moisture',
    'gt',
    70,
    d.id,
    'off',
    '{}',
    1
FROM device d
WHERE d.device_type = 'pump'
  AND NOT EXISTS (
      SELECT 1
      FROM automation_rule a
      WHERE a.trigger_metric = 'soil_moisture'
        AND a.trigger_condition = 'gt'
        AND a.trigger_value = 70
        AND a.action_type = 'off'
  );

INSERT INTO automation_rule (
    trigger_metric,
    trigger_condition,
    trigger_value,
    action_device_id,
    action_type,
    action_params,
    is_enabled
)
SELECT
    'light_intensity',
    'lt',
    5000,
    d.id,
    'on',
    '{"brightness": 80}',
    1
FROM device d
WHERE d.device_type = 'led'
  AND NOT EXISTS (
      SELECT 1
      FROM automation_rule a
      WHERE a.trigger_metric = 'light_intensity'
        AND a.trigger_condition = 'lt'
        AND a.trigger_value = 5000
        AND a.action_type = 'on'
  );

INSERT INTO automation_rule (
    trigger_metric,
    trigger_condition,
    trigger_value,
    action_device_id,
    action_type,
    action_params,
    is_enabled
)
SELECT
    'co2_level',
    'gt',
    1000,
    d.id,
    'on',
    '{"speed": 100}',
    1
FROM device d
WHERE d.device_type = 'fan'
  AND NOT EXISTS (
      SELECT 1
      FROM automation_rule a
      WHERE a.trigger_metric = 'co2_level'
        AND a.trigger_condition = 'gt'
        AND a.trigger_value = 1000
        AND a.action_type = 'on'
  );

INSERT INTO automation_rule (
    trigger_metric,
    trigger_condition,
    trigger_value,
    action_device_id,
    action_type,
    action_params,
    is_enabled
)
SELECT
    'co2_level',
    'lt',
    600,
    d.id,
    'off',
    '{}',
    1
FROM device d
WHERE d.device_type = 'fan'
  AND NOT EXISTS (
      SELECT 1
      FROM automation_rule a
      WHERE a.trigger_metric = 'co2_level'
        AND a.trigger_condition = 'lt'
        AND a.trigger_value = 600
        AND a.action_type = 'off'
  );

INSERT INTO zone (zone_name, zone_type, description)
SELECT 'Greenhouse A', 'greenhouse', 'Main greenhouse area'
WHERE NOT EXISTS (SELECT 1 FROM zone WHERE zone_name = 'Greenhouse A');
INSERT INTO zone (zone_name, zone_type, description)
SELECT 'Field Test Area', 'field', 'Outdoor test planting area'
WHERE NOT EXISTS (SELECT 1 FROM zone WHERE zone_name = 'Field Test Area');
