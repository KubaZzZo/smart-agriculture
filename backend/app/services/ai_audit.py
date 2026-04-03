from __future__ import annotations

import csv
import io
import json
from datetime import datetime
from pathlib import Path
from typing import Any


class AIOpsAuditService:
    def __init__(self) -> None:
        backend_dir = Path(__file__).resolve().parents[2]
        runtime_dir = backend_dir / "runtime"
        runtime_dir.mkdir(parents=True, exist_ok=True)
        self._log_file = runtime_dir / "ai_ops_audit.jsonl"

    def log(
        self,
        actor: str,
        role: str,
        action: str,
        result: str,
        detail: dict[str, Any] | None = None,
        ip: str = "",
    ) -> None:
        record = {
            "created_at": datetime.utcnow().isoformat(),
            "actor": actor,
            "role": role,
            "action": action,
            "result": result,
            "ip": ip,
            "detail": detail or {},
        }
        with self._log_file.open("a", encoding="utf-8") as fp:
            fp.write(json.dumps(record, ensure_ascii=False) + "\n")

    def list(self, limit: int = 100) -> list[dict[str, Any]]:
        if not self._log_file.exists():
            return []
        rows: list[dict[str, Any]] = []
        with self._log_file.open("r", encoding="utf-8") as fp:
            for line in fp:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except Exception:
                    continue
        limit_value = max(1, min(limit, 2000))
        return rows[-limit_value:]

    def export_csv(self, limit: int = 1000) -> str:
        rows = self.list(limit)
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["created_at", "actor", "role", "action", "result", "ip", "detail"])
        for row in rows:
            writer.writerow([
                row.get("created_at", ""),
                row.get("actor", ""),
                row.get("role", ""),
                row.get("action", ""),
                row.get("result", ""),
                row.get("ip", ""),
                json.dumps(row.get("detail", {}), ensure_ascii=False),
            ])
        return output.getvalue()


ai_audit_service = AIOpsAuditService()
