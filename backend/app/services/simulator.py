import math
import random
from datetime import datetime
from sqlalchemy.orm import Session
from ..models import SensorData, Device
from ..config import settings

# 延迟导入 mqtt_client，避免循环依赖
def _get_real_data():
    """惰性获取 MQTT 真实数据，MQTT 未启用时直接返回 None。"""
    if not settings.MQTT_ENABLED:
        return None
    try:
        from .mqtt_client import get_real_data
        return get_real_data()
    except Exception:
        return None


# 数据范围
RANGES = {
    "temperature": (12.0, 42.0),
    "humidity": (25.0, 98.0),
    "light_intensity": (0.0, 120000.0),
    "co2_level": (280.0, 2500.0),
    "soil_moisture": (8.0, 95.0),
}

# 各指标的"舒适中心值"，数据会围绕这些值做自然波动
CENTER = {
    "temperature": 26.0,
    "humidity": 62.0,
    "light_intensity": 45000.0,
    "co2_level": 550.0,
    "soil_moisture": 48.0,
}

# 短期随机漂移幅度（每次tick的噪声）
DRIFT = {
    "temperature": 0.8,
    "humidity": 1.5,
    "light_intensity": 800.0,
    "co2_level": 30.0,
    "soil_moisture": 0.8,
}

# 全局tick计数器，用于生成平滑的周期性波动
_tick_count = 0

# 天气状态模拟
_weather_state = {
    "type": "sunny",       # sunny / cloudy / rainy
    "duration": 0,         # 剩余持续tick数
    "intensity": 1.0,      # 天气强度 0~1
}


def clamp(value: float, min_val: float, max_val: float) -> float:
    return max(min_val, min(max_val, value))


def get_daylight_factor() -> float:
    """基于当前小时模拟日照周期，返回 0~1 的光照因子"""
    hour = datetime.now().hour + datetime.now().minute / 60.0
    factor = math.sin(math.pi * (hour - 6) / 12)
    return max(0.0, factor)


def _update_weather():
    """随机切换天气状态，模拟晴天/多云/下雨"""
    global _weather_state
    if _weather_state["duration"] > 0:
        _weather_state["duration"] -= 1
        return

    # 天气转换概率
    r = random.random()
    if r < 0.55:
        _weather_state["type"] = "sunny"
        _weather_state["duration"] = random.randint(30, 80)
        _weather_state["intensity"] = random.uniform(0.8, 1.0)
    elif r < 0.85:
        _weather_state["type"] = "cloudy"
        _weather_state["duration"] = random.randint(20, 60)
        _weather_state["intensity"] = random.uniform(0.3, 0.7)
    else:
        _weather_state["type"] = "rainy"
        _weather_state["duration"] = random.randint(15, 40)
        _weather_state["intensity"] = random.uniform(0.6, 1.0)


def _smooth_noise(tick: int, period: float, amplitude: float) -> float:
    """用多个正弦波叠加模拟平滑的自然波动"""
    v = 0.0
    v += math.sin(2 * math.pi * tick / period) * amplitude * 0.5
    v += math.sin(2 * math.pi * tick / (period * 0.37) + 1.7) * amplitude * 0.3
    v += math.sin(2 * math.pi * tick / (period * 2.1) + 3.2) * amplitude * 0.2
    return v


def _mean_revert(current: float, center: float, strength: float = 0.03) -> float:
    """均值回归，防止数据一直漂到极端值"""
    return current + (center - current) * strength


def generate_sensor_data(db: Session, last_data: SensorData = None) -> SensorData:
    """
    生成一条新的传感器数据。
    优先级：① MQTT 真实数据  ② 物理模拟数据
    """
    global _tick_count
    _tick_count += 1
    _update_weather()

    # === 优先使用来自 Easy IoT 的真实传感器数据 ===
    real = _get_real_data()
    if real is not None and all(real[k] is not None for k in real):
        data = SensorData(
            temperature=round(real["temperature"], 1),
            humidity=round(real["humidity"], 1),
            light_intensity=round(real["light_intensity"], 1),
            co2_level=round(real["co2_level"], 1),
            soil_moisture=round(real["soil_moisture"], 1),
        )
        db.add(data)
        db.commit()
        db.refresh(data)
        return data

    # === 回退：物理模拟数据 ===
    devices = {d.device_type: d for d in db.query(Device).all()}
    weather = _weather_state["type"]
    w_intensity = _weather_state["intensity"]

    # 基线值
    if last_data:
        temp = last_data.temperature
        hum = last_data.humidity
        light = last_data.light_intensity
        co2 = last_data.co2_level
        soil = last_data.soil_moisture
    else:
        temp = CENTER["temperature"]
        hum = CENTER["humidity"]
        light = CENTER["light_intensity"]
        co2 = CENTER["co2_level"]
        soil = CENTER["soil_moisture"]

    # === 1. 均值回归（防止漂移到极端） ===
    temp = _mean_revert(temp, CENTER["temperature"], 0.02)
    hum = _mean_revert(hum, CENTER["humidity"], 0.02)
    co2 = _mean_revert(co2, CENTER["co2_level"], 0.015)
    soil = _mean_revert(soil, CENTER["soil_moisture"], 0.01)

    # === 2. 平滑周期性波动（模拟自然节律） ===
    temp += _smooth_noise(_tick_count, 120, 3.0)
    hum += _smooth_noise(_tick_count, 90, 5.0)
    co2 += _smooth_noise(_tick_count, 150, 80.0)
    soil += _smooth_noise(_tick_count, 200, 3.0)

    # === 3. 随机漂移（短期噪声） ===
    temp += random.gauss(0, DRIFT["temperature"])
    hum += random.gauss(0, DRIFT["humidity"])
    light += random.gauss(0, DRIFT["light_intensity"])
    co2 += random.gauss(0, DRIFT["co2_level"])
    soil += random.gauss(0, DRIFT["soil_moisture"])

    # === 4. 日夜周期 ===
    daylight = get_daylight_factor()

    # 天气影响日照
    if weather == "cloudy":
        daylight *= (0.3 + 0.4 * (1 - w_intensity))
    elif weather == "rainy":
        daylight *= (0.1 + 0.2 * (1 - w_intensity))

    light = light * 0.15 + 80000.0 * daylight * 0.85
    temp += (daylight - 0.5) * 3.5  # 白天暖，夜晚凉

    # === 5. 天气对各指标的影响 ===
    if weather == "rainy":
        hum += 3.0 * w_intensity
        soil += 1.5 * w_intensity
        temp -= 2.0 * w_intensity
        co2 -= 15.0 * w_intensity
    elif weather == "cloudy":
        hum += 1.0 * w_intensity
        temp -= 0.5 * w_intensity

    # === 6. 设备联动反馈 ===
    pump = devices.get("pump")
    if pump and pump.status == 1:
        soil += 2.5
        hum += 0.5
    else:
        soil -= 0.3  # 自然蒸发

    valve = devices.get("valve")
    if valve and valve.status == 1:
        hum += 1.5
        temp -= 0.3  # 蒸发降温

    fan = devices.get("fan")
    if fan and fan.status == 1:
        temp -= 1.0
        co2 -= 10.0  # 通风降CO2

    led = devices.get("led")
    if led and led.status == 1:
        brightness = 80
        if led.params and isinstance(led.params, dict):
            brightness = led.params.get("brightness", 80)
        light += 6000.0 * (brightness / 100.0)
        temp += 0.3  # LED发热

    # === 7. 异常注入（8%概率，更多样化） ===
    if random.random() < 0.08:
        anomaly = random.choice(["temp_spike", "temp_drop", "hum_spike", "co2_spike", "soil_dry"])
        if anomaly == "temp_spike":
            temp += random.uniform(5.0, 10.0)
        elif anomaly == "temp_drop":
            temp -= random.uniform(4.0, 8.0)
        elif anomaly == "hum_spike":
            hum += random.uniform(10.0, 20.0)
        elif anomaly == "co2_spike":
            co2 += random.uniform(200.0, 500.0)
        elif anomaly == "soil_dry":
            soil -= random.uniform(8.0, 15.0)

    # === 8. 钳位到合法范围 ===
    temp = clamp(temp, *RANGES["temperature"])
    hum = clamp(hum, *RANGES["humidity"])
    light = clamp(light, *RANGES["light_intensity"])
    co2 = clamp(co2, *RANGES["co2_level"])
    soil = clamp(soil, *RANGES["soil_moisture"])

    data = SensorData(
        temperature=round(temp, 1),
        humidity=round(hum, 1),
        light_intensity=round(light, 1),
        co2_level=round(co2, 1),
        soil_moisture=round(soil, 1),
    )
    db.add(data)
    db.commit()
    db.refresh(data)
    return data
