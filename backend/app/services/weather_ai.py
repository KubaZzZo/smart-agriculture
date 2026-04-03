from __future__ import annotations

from datetime import datetime, timedelta
from random import uniform


def build_weather_forecast(
    current_temp: float,
    current_humidity: float,
    current_weather: str,
    horizon_hours: int,
) -> list[dict[str, float | str]]:
    horizon = max(1, min(horizon_hours, 72))
    now = datetime.utcnow()
    rows: list[dict[str, float | str]] = []

    for i in range(horizon):
        # Simple trend model: day-night temperature wave + stochastic drift.
        hour = (now + timedelta(hours=i)).hour
        day_factor = 2.5 if 10 <= hour <= 16 else (-1.8 if hour <= 5 or hour >= 21 else 0.6)
        temp = round(current_temp + day_factor + uniform(-0.9, 0.9), 1)
        humidity = round(max(25.0, min(95.0, current_humidity - day_factor * 0.8 + uniform(-2.5, 2.5))), 1)

        rows.append(
            {
                "time": (now + timedelta(hours=i)).isoformat(),
                "weather": current_weather,
                "temperature": temp,
                "humidity": humidity,
            }
        )

    return rows


def build_control_suggestion(forecast: list[dict[str, float | str]]) -> list[str]:
    if not forecast:
        return ["无预测数据，维持当前策略"]

    max_temp = max(float(item["temperature"]) for item in forecast)
    min_temp = min(float(item["temperature"]) for item in forecast)
    max_humidity = max(float(item["humidity"]) for item in forecast)
    min_humidity = min(float(item["humidity"]) for item in forecast)

    advice: list[str] = []
    if max_temp >= 33:
        advice.append("未来高温风险较高，建议提前提高通风和补水频率")
    if min_temp <= 12:
        advice.append("夜间低温风险存在，建议降低灌溉强度并保温")
    if max_humidity >= 85:
        advice.append("湿度可能过高，建议风机联动除湿")
    if min_humidity <= 35:
        advice.append("湿度偏低，建议提升喷淋或灌溉时长")
    if not advice:
        advice.append("未来微气候波动平稳，维持当前自动策略")

    return advice
