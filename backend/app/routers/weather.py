from __future__ import annotations

from fastapi import APIRouter, Query

from ..schemas import (
    WeatherForecastPoint,
    WeatherPredictRequest,
    WeatherPredictResponse,
    WeatherResponse,
)
from ..services.weather_ai import build_control_suggestion
from ..services.weather_provider import fetch_weather_forecast, geocode_city

router = APIRouter()


def _resolve_location(city: str, latitude: float | None, longitude: float | None) -> tuple[str, float, float]:
    if latitude is not None and longitude is not None:
        return (city or "custom", float(latitude), float(longitude))
    geocode = geocode_city(city)
    if geocode:
        return (city, geocode[0], geocode[1])
    return (city or "fallback", 39.9042, 116.4074)  # Beijing fallback


@router.get("", response_model=WeatherResponse)
def get_weather(
    city: str = Query("Beijing"),
    latitude: float | None = Query(None),
    longitude: float | None = Query(None),
):
    city_value, lat, lon = _resolve_location(city, latitude, longitude)
    rows = fetch_weather_forecast(latitude=lat, longitude=lon, horizon_hours=1)
    first = rows[0]
    suggestions = build_control_suggestion(rows)
    return WeatherResponse(
        city=city_value,
        temperature=float(first["temperature"]),
        humidity=float(first["humidity"]),
        weather=str(first["weather"]),
        wind="auto",
        suggestion=suggestions[0] if suggestions else "keep current strategy",
    )


@router.post("/predictive", response_model=WeatherPredictResponse)
def predictive_weather(payload: WeatherPredictRequest):
    city_value, lat, lon = _resolve_location(payload.city, payload.latitude, payload.longitude)
    horizon = max(1, min(72, payload.horizon_hours))
    rows = fetch_weather_forecast(latitude=lat, longitude=lon, horizon_hours=horizon)
    suggestions = build_control_suggestion(rows)
    points = [WeatherForecastPoint(**row) for row in rows]
    return WeatherPredictResponse(
        city=city_value,
        latitude=lat,
        longitude=lon,
        horizon_hours=horizon,
        points=points,
        suggestions=suggestions,
    )

