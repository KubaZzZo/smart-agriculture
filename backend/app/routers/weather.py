import random
from datetime import datetime
from fastapi import APIRouter
from ..schemas import WeatherResponse

router = APIRouter()

# 模拟天气数据（比赛演示用，实际可接入和风天气等API）
WEATHER_TYPES = ["晴", "多云", "阴", "小雨", "阵雨"]
WIND_TYPES = ["微风", "东风3级", "南风2级", "西北风3级"]


def get_irrigation_suggestion(weather: str, temperature: float, humidity: float) -> str:
    if "雨" in weather:
        return "今日有降雨，建议减少灌溉量或暂停灌溉"
    if temperature > 35:
        return "高温天气，建议增加灌溉频次，避开正午时段"
    if temperature < 10:
        return "低温天气，建议减少灌溉量，防止冻害"
    if humidity > 80:
        return "空气湿度较高，适当减少灌溉"
    return "天气适宜，按正常计划灌溉即可"


@router.get("", response_model=WeatherResponse)
def get_weather():
    """获取天气数据（模拟）"""
    hour = datetime.now().hour
    # 根据时间段模拟合理温度
    if 6 <= hour <= 10:
        base_temp = 20
    elif 10 < hour <= 14:
        base_temp = 30
    elif 14 < hour <= 18:
        base_temp = 27
    else:
        base_temp = 18

    temperature = round(base_temp + random.uniform(-3, 3), 1)
    humidity = round(random.uniform(40, 80), 1)
    weather = random.choice(WEATHER_TYPES)
    wind = random.choice(WIND_TYPES)
    suggestion = get_irrigation_suggestion(weather, temperature, humidity)

    return WeatherResponse(
        city="智慧农场",
        temperature=temperature,
        humidity=humidity,
        weather=weather,
        wind=wind,
        suggestion=suggestion,
    )
