from __future__ import annotations

import json
from datetime import datetime
from typing import Any
from urllib.error import URLError
from urllib.request import Request, urlopen

from ..config import settings
from .edge_autonomy import edge_autonomy_service


def _local_autofix_plan(incident_type: str, context: dict[str, Any]) -> list[dict[str, Any]]:
    key = incident_type.strip().lower()
    if key == "pest":
        return [
            {"action": "device_control", "payload": {"device_type": "fan", "status": 1, "mode": "vent"}},
            {"action": "device_control", "payload": {"device_type": "spray", "status": 1}},
        ]
    if key == "weather":
        return [
            {"action": "device_control", "payload": {"device_type": "pump", "status": 0}},
            {"action": "device_control", "payload": {"device_type": "fan", "status": 1, "mode": "protect"}},
        ]
    if key == "sensor_drift":
        return [
            {"action": "device_params", "payload": {"device_id": int(context.get("device_id", 1)), "params": {"calibration_mode": "auto"}}}
        ]
    return [{"action": "incident_step", "payload": {"incident_type": incident_type, "context": context}}]


def _fetch_openclaw_plan(incident_type: str, context: dict[str, Any]) -> list[dict[str, Any]] | None:
    if not settings.OPENCLAW_ENABLED or not settings.OPENCLAW_API_KEY.strip():
        return None
    body = json.dumps({"incident_type": incident_type, "context": context}).encode("utf-8")
    req = Request(
        f"{settings.OPENCLAW_API_BASE.rstrip('/')}/autofix",
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {settings.OPENCLAW_API_KEY}",
            "User-Agent": "smart-agriculture/1.0",
        },
        method="POST",
    )
    try:
        with urlopen(req, timeout=8.0) as response:  # nosec B310 - controlled url from settings
            payload = response.read().decode("utf-8")
        data = json.loads(payload)
        plan = data.get("actions", [])
        if isinstance(plan, list):
            normalized: list[dict[str, Any]] = []
            for item in plan:
                if not isinstance(item, dict):
                    continue
                action = str(item.get("action", "")).strip()
                payload_obj = item.get("payload", {})
                if action and isinstance(payload_obj, dict):
                    normalized.append({"action": action, "payload": payload_obj})
            if normalized:
                return normalized
    except (URLError, TimeoutError, ValueError, json.JSONDecodeError):
        return None
    return None


def auto_fix_incident(
    incident_type: str,
    context: dict[str, Any],
    dry_run: bool = False,
) -> dict[str, Any]:
    plan = _fetch_openclaw_plan(incident_type, context) or _local_autofix_plan(incident_type, context)
    if dry_run:
        return {
            "source": "openclaw" if settings.OPENCLAW_ENABLED and settings.OPENCLAW_API_KEY.strip() else "local_fallback",
            "incident_type": incident_type,
            "dry_run": True,
            "actions": plan,
            "submitted": [],
        }

    submitted: list[dict[str, Any]] = []
    base = int(datetime.utcnow().timestamp())
    for index, item in enumerate(plan, start=1):
        result = edge_autonomy_service.enqueue_or_execute(
            task_id=f"openclaw-{incident_type}-{base}-{index}",
            action=item["action"],
            payload=item["payload"],
        )
        submitted.append(result)

    return {
        "source": "openclaw" if settings.OPENCLAW_ENABLED and settings.OPENCLAW_API_KEY.strip() else "local_fallback",
        "incident_type": incident_type,
        "dry_run": False,
        "actions": plan,
        "submitted": submitted,
    }

