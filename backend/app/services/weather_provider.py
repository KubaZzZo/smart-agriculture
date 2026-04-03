from __future__ import annotations

import json
from datetime import datetime, timedelta
from random import uniform
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from ..config import settings


def _safe_float(value: object, default: float) -> float:
    try:
        return float(value)
    except Exception:
        return default


def _http_get_json(url: str, timeout: float = 6.0) -> dict:
    request = Request(url, headers={"User-Agent": "smart-agriculture/1.0"})
    with urlopen(request, timeout=timeout) as response:  # nosec B310 - controlled url from settings
        payload = response.read().decode("utf-8")
    data = json.loads(payload)
    if not isinstance(data, dict):
        raise ValueError("invalid json payload")
    return data


def geocode_city(city: str) -> tuple[float, float] | None:
    city_value = city.strip()
    if not city_value:
        return None
    query = urlencode({"name": city_value, "count": 1, "language": "zh", "format": "json"})
    url = f"{settings.WEATHER_GEOCODE_API_BASE}?{query}"
    try:
        data = _http_get_json(url)
        results = data.get("results")
        if isinstance(results, list) and results:
            first = results[0]
            return (_safe_float(first.get("latitude"), 0.0), _safe_float(first.get("longitude"), 0.0))
    except Exception:
        return None
    return None


def fetch_weather_forecast(
    latitude: float,
    longitude: float,
    horizon_hours: int,
) -> list[dict[str, float | str]]:
    hours = max(1, min(72, horizon_hours))
    query = urlencode(
        {
            "latitude": latitude,
            "longitude": longitude,
            "hourly": "temperature_2m,relative_humidity_2m,weather_code",
            "forecast_days": 4,
            "timezone": "auto",
        }
    )
    url = f"{settings.WEATHER_API_BASE}?{query}"
    try:
        data = _http_get_json(url)
        hourly = data.get("hourly", {})
        times = list(hourly.get("time", []) or [])
        temps = list(hourly.get("temperature_2m", []) or [])
        hums = list(hourly.get("relative_humidity_2m", []) or [])
        weather_codes = list(hourly.get("weather_code", []) or [])
        rows: list[dict[str, float | str]] = []
        for index in range(min(hours, len(times), len(temps), len(hums))):
            rows.append(
                {
                    "time": str(times[index]),
                    "weather": str(weather_codes[index]) if index < len(weather_codes) else "unknown",
                    "temperature": _safe_float(temps[index], 0.0),
                    "humidity": _safe_float(hums[index], 0.0),
                }
            )
        if rows:
            return rows
    except (URLError, TimeoutError, ValueError, json.JSONDecodeError):
        pass

    # Fallback local forecast if weather API is unavailable.
    now = datetime.utcnow()
    fallback: list[dict[str, float | str]] = []
    base_temp = 24.0
    base_humidity = 60.0
    for index in range(hours):
        current = now + timedelta(hours=index)
        hour = current.hour
        day_factor = 2.4 if 10 <= hour <= 16 else (-1.6 if hour <= 5 or hour >= 21 else 0.5)
        temp = round(base_temp + day_factor + uniform(-0.8, 0.8), 1)
        humidity = round(max(30.0, min(95.0, base_humidity - day_factor * 0.9 + uniform(-2.0, 2.0))), 1)
        fallback.append(
            {
                "time": current.isoformat(),
                "weather": "fallback",
                "temperature": temp,
                "humidity": humidity,
            }
        )
    return fallback

