from __future__ import annotations

import json
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any


class PestStreamService:
    def __init__(self) -> None:
        backend_dir = Path(__file__).resolve().parents[2]
        runtime_dir = backend_dir / "runtime"
        runtime_dir.mkdir(parents=True, exist_ok=True)
        self._state_file = runtime_dir / "pest_stream_state.json"
        self._records: list[dict[str, Any]] = []
        self._load()

    def _load(self) -> None:
        if not self._state_file.exists():
            self._records = []
            return
        try:
            data = json.loads(self._state_file.read_text(encoding="utf-8"))
            items = data.get("records", [])
            if isinstance(items, list):
                self._records = [dict(x) for x in items if isinstance(x, dict)][-1000:]
                return
        except Exception:
            pass
        self._records = []

    def _save(self) -> None:
        data = {"records": self._records[-1000:]}
        self._state_file.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    def record(
        self,
        source: str,
        result: dict[str, Any],
        camera_id: str = "",
        zone_id: str = "",
    ) -> dict[str, Any]:
        item = {
            "created_at": datetime.utcnow().isoformat(),
            "source": (source or "unknown").strip().lower() or "unknown",
            "camera_id": camera_id.strip(),
            "zone_id": zone_id.strip(),
            "risk_level": str(result.get("risk_level", "unknown")),
            "confidence": float(result.get("confidence", 0.0) or 0.0),
            "pest_type": str(result.get("pest_type", "unknown")),
            "engine": str(result.get("engine", "unknown")),
            "quality_score": float(result.get("quality_score", 0.0) or 0.0),
            "reason": str(result.get("reason", "")),
        }
        self._records.append(item)
        if len(self._records) > 1000:
            self._records = self._records[-1000:]
        self._save()
        return item

    def latest(self, source: str = "") -> dict[str, Any] | None:
        source_key = (source or "").strip().lower()
        for item in reversed(self._records):
            if source_key and item.get("source") != source_key:
                continue
            return dict(item)
        return None

    def recent(self, limit: int = 20, source: str = "") -> list[dict[str, Any]]:
        return self.query(limit=limit, source=source)

    def query(
        self,
        limit: int = 20,
        source: str = "",
        since_minutes: int = 0,
        risk_levels: set[str] | None = None,
    ) -> list[dict[str, Any]]:
        source_key = (source or "").strip().lower()
        now = datetime.utcnow()
        since = None
        if since_minutes > 0:
            since = now - timedelta(minutes=max(1, min(since_minutes, 24 * 60)))
        risk_keys = {x.lower().strip() for x in (risk_levels or set()) if x and x.strip()}
        rows: list[dict[str, Any]] = []
        for item in reversed(self._records):
            if source_key and item.get("source") != source_key:
                continue
            created_at_text = str(item.get("created_at", ""))
            if since is not None:
                try:
                    created_at = datetime.fromisoformat(created_at_text)
                except Exception:
                    continue
                if created_at < since:
                    continue
            risk_level = str(item.get("risk_level", "unknown")).strip().lower()
            if risk_keys and risk_level not in risk_keys:
                continue
            rows.append(dict(item))
            if len(rows) >= max(1, min(limit, 200)):
                break
        return rows

    def final_summary(
        self,
        window_minutes: int = 60,
        source: str = "",
        risk_levels: set[str] | None = None,
    ) -> dict[str, Any]:
        source_key = (source or "").strip().lower()
        now = datetime.utcnow()
        since = now - timedelta(minutes=max(1, min(window_minutes, 24 * 60)))
        risk_keys = {x.lower().strip() for x in (risk_levels or set()) if x and x.strip()}

        selected: list[dict[str, Any]] = []
        for item in self._records:
            if source_key and item.get("source") != source_key:
                continue
            created_at_text = str(item.get("created_at", ""))
            try:
                created_at = datetime.fromisoformat(created_at_text)
            except Exception:
                continue
            if created_at >= since:
                risk_level = str(item.get("risk_level", "unknown")).strip().lower()
                if risk_keys and risk_level not in risk_keys:
                    continue
                selected.append(item)

        risk_counts = {"high": 0, "medium": 0, "low": 0, "unknown": 0}
        avg_conf = 0.0
        avg_quality = 0.0
        pest_counter: dict[str, int] = {}
        source_counter: dict[str, int] = {}
        for item in selected:
            risk = str(item.get("risk_level", "unknown")).lower()
            if risk not in risk_counts:
                risk = "unknown"
            risk_counts[risk] += 1
            avg_conf += float(item.get("confidence", 0.0) or 0.0)
            avg_quality += float(item.get("quality_score", 0.0) or 0.0)
            pest_type = str(item.get("pest_type", "unknown"))
            pest_counter[pest_type] = pest_counter.get(pest_type, 0) + 1
            source_name = str(item.get("source", "unknown")).strip().lower() or "unknown"
            source_counter[source_name] = source_counter.get(source_name, 0) + 1

        total = len(selected)
        top_pest = "none"
        if pest_counter:
            top_pest = sorted(pest_counter.items(), key=lambda x: x[1], reverse=True)[0][0]

        latest_item = self.latest(source=source_key) if source_key else self.latest()
        risk_score = 0.0
        if total:
            risk_score = (
                risk_counts["high"] * 1.0
                + risk_counts["medium"] * 0.6
                + risk_counts["low"] * 0.2
                + risk_counts["unknown"] * 0.3
            ) / total

        trend = "stable"
        if total >= 4:
            half = max(1, total // 2)
            old_part = selected[:half]
            new_part = selected[half:]

            def _risk_weight(items: list[dict[str, Any]]) -> float:
                if not items:
                    return 0.0
                score = 0.0
                for row in items:
                    level = str(row.get("risk_level", "unknown")).lower()
                    if level == "high":
                        score += 1.0
                    elif level == "medium":
                        score += 0.6
                    elif level == "low":
                        score += 0.2
                    else:
                        score += 0.3
                return score / len(items)

            old_score = _risk_weight(old_part)
            new_score = _risk_weight(new_part)
            delta = new_score - old_score
            if delta >= 0.12:
                trend = "up"
            elif delta <= -0.12:
                trend = "down"

        return {
            "window_minutes": window_minutes,
            "source": source_key or "all",
            "window_start": since.isoformat(),
            "window_end": now.isoformat(),
            "total": total,
            "risk_counts": risk_counts,
            "avg_confidence": round(avg_conf / total, 3) if total else 0.0,
            "avg_quality": round(avg_quality / total, 3) if total else 0.0,
            "risk_index": round(risk_score, 3),
            "high_risk_ratio": round(risk_counts["high"] / total, 3) if total else 0.0,
            "trend": trend,
            "source_breakdown": source_counter,
            "top_pest_type": top_pest,
            "latest": latest_item,
        }


pest_stream_service = PestStreamService()
