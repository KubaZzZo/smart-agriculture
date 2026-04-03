from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass
class ZoneSignal:
    zone_id: int
    zone_name: str
    temperature: float
    humidity: float
    soil_moisture: float
    target_temperature: float
    target_humidity: float
    target_soil_moisture: float


def _bounded_ratio(delta: float, divisor: float) -> float:
    if divisor <= 0:
        return 0.0
    value = abs(delta) / divisor
    return min(1.0, max(0.0, value))


def _zone_score(zone: ZoneSignal) -> float:
    temp_delta = zone.temperature - zone.target_temperature
    humidity_delta = zone.humidity - zone.target_humidity
    soil_delta = zone.soil_moisture - zone.target_soil_moisture

    temp_risk = _bounded_ratio(temp_delta, 6.0)
    humidity_risk = _bounded_ratio(humidity_delta, 16.0)
    soil_risk = _bounded_ratio(soil_delta, 18.0)

    # Weighted matrix: temperature + humidity + soil moisture.
    return round(temp_risk * 0.38 + humidity_risk * 0.34 + soil_risk * 0.28, 3)


def _zone_actions(zone: ZoneSignal) -> list[str]:
    actions: list[str] = []
    temp_delta = zone.temperature - zone.target_temperature
    humidity_delta = zone.humidity - zone.target_humidity
    soil_delta = zone.soil_moisture - zone.target_soil_moisture

    if temp_delta > 1.5:
        actions.append("Increase fan speed and ventilation to reduce temperature")
    elif temp_delta < -1.5:
        actions.append("Reduce ventilation to preserve heat")

    if humidity_delta > 6:
        actions.append("Enable dehumidification mode and increase airflow")
    elif humidity_delta < -6:
        actions.append("Increase misting cadence to raise humidity")

    if soil_delta < -4:
        actions.append("Trigger irrigation pulse and re-check soil moisture in 10 minutes")
    elif soil_delta > 7:
        actions.append("Pause irrigation and monitor root-zone oxygen level")

    if not actions:
        actions.append("Microclimate is stable, keep current strategy")

    return actions


def optimize_with_matrix(zones: list[dict]) -> dict:
    zone_outputs: list[dict] = []
    scores: list[float] = []
    for raw in zones:
        zone = ZoneSignal(
            zone_id=int(raw["zone_id"]),
            zone_name=str(raw["zone_name"]),
            temperature=float(raw["temperature"]),
            humidity=float(raw["humidity"]),
            soil_moisture=float(raw["soil_moisture"]),
            target_temperature=float(raw["target_temperature"]),
            target_humidity=float(raw["target_humidity"]),
            target_soil_moisture=float(raw["target_soil_moisture"]),
        )
        score = _zone_score(zone)
        scores.append(score)
        zone_outputs.append(
            {
                "zone_id": zone.zone_id,
                "zone_name": zone.zone_name,
                "actions": _zone_actions(zone),
                "risk_score": score,
            }
        )

    system_risk = round(sum(scores) / len(scores), 3) if scores else 0.0
    return {
        "generated_at": datetime.utcnow().isoformat(),
        "system_risk_score": system_risk,
        "actions": zone_outputs,
    }

