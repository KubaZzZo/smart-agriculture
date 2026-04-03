from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any

from ..config import settings


class HuaweiBridgeService:
    def __init__(self) -> None:
        backend_dir = Path(__file__).resolve().parents[2]
        runtime_dir = backend_dir / "runtime"
        runtime_dir.mkdir(parents=True, exist_ok=True)
        self._state_file = runtime_dir / "huawei_bridge_state.json"
        self._state = {"watch_samples": [], "handoffs": [], "xiaoyi_commands": []}
        self._load()

    def _load(self) -> None:
        if not self._state_file.exists():
            return
        try:
            data = json.loads(self._state_file.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                self._state["watch_samples"] = list(data.get("watch_samples", []))[-1000:]
                self._state["handoffs"] = list(data.get("handoffs", []))[-500:]
                self._state["xiaoyi_commands"] = list(data.get("xiaoyi_commands", []))[-500:]
        except Exception:
            return

    def _save(self) -> None:
        self._state_file.write_text(
            json.dumps(self._state, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def valid_watch_token(self, token: str) -> bool:
        configured = [item.strip() for item in settings.HUAWEI_WATCH_TOKENS.split(",") if item.strip()]
        if not configured:
            return False
        return token in configured

    def valid_xiaoyi_secret(self, secret: str) -> bool:
        expected = settings.XIAOYI_SHARED_SECRET.strip()
        if not expected:
            return False
        return expected == secret

    def ingest_watch_sample(self, payload: dict[str, Any]) -> dict[str, Any]:
        heart_rate = float(payload.get("heart_rate", 0.0) or 0.0)
        steps = int(payload.get("steps", 0) or 0)
        skin_temperature = float(payload.get("skin_temperature", 0.0) or 0.0)
        battery = int(payload.get("battery", 0) or 0)
        signal_strength = int(payload.get("signal_strength", 0) or 0)

        risk_flags: list[str] = []
        if heart_rate >= 125:
            risk_flags.append("high_heart_rate")
        if skin_temperature >= 37.5:
            risk_flags.append("heat_stress")
        if battery <= 15:
            risk_flags.append("low_battery")
        if signal_strength <= 1:
            risk_flags.append("weak_signal")

        workload_level = "normal"
        if heart_rate >= 125 or steps >= 20000:
            workload_level = "high"
        elif heart_rate >= 105 or steps >= 12000:
            workload_level = "medium"

        row = {
            "received_at": datetime.utcnow().isoformat(),
            "watch_id": str(payload.get("watch_id", "watch-default")),
            "heart_rate": heart_rate,
            "steps": steps,
            "skin_temperature": skin_temperature,
            "battery": battery,
            "signal_strength": signal_strength,
            "zone_id": str(payload.get("zone_id", "")),
            "workload_level": workload_level,
            "risk_flags": risk_flags,
        }
        self._state["watch_samples"].append(row)
        self._state["watch_samples"] = self._state["watch_samples"][-1000:]
        self._save()

        tips: list[str] = []
        if heart_rate >= 125:
            tips.append("Field operator workload is high, reduce manual patrol duration")
        if skin_temperature >= 37.5:
            tips.append("Potential heat stress, prioritize shaded operation and hydration")
        if battery <= 15:
            tips.append("Watch battery is low, switch to low-power telemetry mode")
        if signal_strength <= 1:
            tips.append("Watch signal is weak, prioritize nearby relay or offline cache mode")
        if not tips:
            tips.append("Operator wearable metrics look healthy")

        return {"accepted": True, "tips": tips, "sample": row, "risk_flags": risk_flags}

    def record_handoff(self, payload: dict[str, Any]) -> dict[str, Any]:
        method = str(payload.get("method", "nfc")).lower().strip()
        if method not in {"nfc", "distributed_bus"}:
            method = "nfc"
        ttl_seconds = int(payload.get("ttl_seconds", 180) or 180)
        ttl_seconds = max(30, min(ttl_seconds, 30 * 60))
        now = datetime.utcnow()
        expires_at = datetime.utcfromtimestamp(now.timestamp() + ttl_seconds).isoformat()
        row = {
            "handoff_id": str(payload.get("handoff_id", f"handoff-{int(now.timestamp())}")),
            "created_at": now.isoformat(),
            "source_device": str(payload.get("source_device", "unknown")),
            "target_device": str(payload.get("target_device", "unknown")),
            "method": method,
            "payload": dict(payload.get("payload", {})),
            "ttl_seconds": ttl_seconds,
            "expires_at": expires_at,
            "status": "active",
        }
        self._state["handoffs"].append(row)
        self._state["handoffs"] = self._state["handoffs"][-500:]
        self._save()
        return {"accepted": True, "handoff": row}

    def ingest_xiaoyi_command(self, payload: dict[str, Any]) -> dict[str, Any]:
        row = {
            "received_at": datetime.utcnow().isoformat(),
            "intent": str(payload.get("intent", "unknown")),
            "text": str(payload.get("text", "")),
            "params": dict(payload.get("params", {})),
        }
        self._state["xiaoyi_commands"].append(row)
        self._state["xiaoyi_commands"] = self._state["xiaoyi_commands"][-500:]
        self._save()
        return {"accepted": True, "command": row}

    def status(self) -> dict[str, Any]:
        now = datetime.utcnow()
        active_handoffs = 0
        expired_handoffs = 0
        for handoff in self._state["handoffs"]:
            expires_at = str(handoff.get("expires_at", ""))
            try:
                expired = datetime.fromisoformat(expires_at) < now
            except Exception:
                expired = False
            if expired:
                expired_handoffs += 1
            else:
                active_handoffs += 1
        latest_watch = self._state["watch_samples"][-1] if self._state["watch_samples"] else None
        latest_handoff = self._state["handoffs"][-1] if self._state["handoffs"] else None
        latest_xiaoyi = self._state["xiaoyi_commands"][-1] if self._state["xiaoyi_commands"] else None
        return {
            "watch_samples": len(self._state["watch_samples"]),
            "handoffs": len(self._state["handoffs"]),
            "xiaoyi_commands": len(self._state["xiaoyi_commands"]),
            "active_handoffs": active_handoffs,
            "expired_handoffs": expired_handoffs,
            "latest_watch_sample": latest_watch,
            "latest_handoff": latest_handoff,
            "latest_xiaoyi_command": latest_xiaoyi,
        }

    def recent_watch_samples(self, limit: int = 20, zone_id: str = "") -> list[dict[str, Any]]:
        max_items = max(1, min(limit, 200))
        zone_key = zone_id.strip()
        rows: list[dict[str, Any]] = []
        for item in reversed(self._state["watch_samples"]):
            if zone_key and str(item.get("zone_id", "")) != zone_key:
                continue
            rows.append(dict(item))
            if len(rows) >= max_items:
                break
        return rows

    def recent_handoffs(self, limit: int = 20, active_only: bool = False) -> list[dict[str, Any]]:
        max_items = max(1, min(limit, 200))
        now = datetime.utcnow()
        rows: list[dict[str, Any]] = []
        for item in reversed(self._state["handoffs"]):
            row = dict(item)
            expires_at = str(row.get("expires_at", ""))
            try:
                is_active = datetime.fromisoformat(expires_at) >= now
            except Exception:
                is_active = True
            row["status"] = "active" if is_active else "expired"
            if active_only and not is_active:
                continue
            rows.append(row)
            if len(rows) >= max_items:
                break
        return rows

    def recent_xiaoyi_commands(self, limit: int = 20, intent: str = "") -> list[dict[str, Any]]:
        max_items = max(1, min(limit, 200))
        intent_key = intent.strip().lower()
        rows: list[dict[str, Any]] = []
        for item in reversed(self._state["xiaoyi_commands"]):
            if intent_key and str(item.get("intent", "")).strip().lower() != intent_key:
                continue
            rows.append(dict(item))
            if len(rows) >= max_items:
                break
        return rows


huawei_bridge_service = HuaweiBridgeService()
