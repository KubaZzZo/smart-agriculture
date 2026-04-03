from __future__ import annotations

import json
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any


@dataclass
class EdgeTask:
    task_id: str
    action: str
    payload: dict[str, Any]
    retry_count: int = 0
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class EdgeEvent:
    event_type: str
    detail: dict[str, Any]
    created_at: datetime = field(default_factory=datetime.utcnow)


class EdgeAutonomyService:
    """Persistent edge autonomy state for offline-first control."""

    def __init__(self) -> None:
        self._online: bool = True
        self._queue: list[EdgeTask] = []
        self._dead_letter: list[dict[str, Any]] = []
        self._history: list[EdgeEvent] = []
        self._seen_task_ids: list[str] = []
        self._max_retries: int = 3
        self._executor: Callable[[str, dict[str, Any]], dict[str, Any]] | None = None

        backend_dir = Path(__file__).resolve().parents[2]
        runtime_dir = backend_dir / "runtime"
        runtime_dir.mkdir(parents=True, exist_ok=True)
        self._state_file = runtime_dir / "edge_autonomy_state.json"

        self._load_state()

    def set_executor(self, executor: Callable[[str, dict[str, Any]], dict[str, Any]]) -> None:
        self._executor = executor

    def _now(self) -> str:
        return datetime.utcnow().isoformat()

    def _log_event(self, event_type: str, detail: dict[str, Any]) -> None:
        self._history.append(EdgeEvent(event_type=event_type, detail=detail))
        if len(self._history) > 500:
            self._history = self._history[-500:]

    def _mark_seen(self, task_id: str) -> None:
        if task_id in self._seen_task_ids:
            return
        self._seen_task_ids.append(task_id)
        if len(self._seen_task_ids) > 2000:
            self._seen_task_ids = self._seen_task_ids[-2000:]

    def _task_to_dict(self, task: EdgeTask) -> dict[str, Any]:
        return {
            "task_id": task.task_id,
            "action": task.action,
            "payload": task.payload,
            "retry_count": task.retry_count,
            "created_at": task.created_at.isoformat(),
        }

    def _event_to_dict(self, event: EdgeEvent) -> dict[str, Any]:
        return {
            "event_type": event.event_type,
            "detail": event.detail,
            "created_at": event.created_at.isoformat(),
        }

    def _save_state(self) -> None:
        data = {
            "online": self._online,
            "queue": [self._task_to_dict(task) for task in self._queue],
            "dead_letter": self._dead_letter[-500:],
            "history": [self._event_to_dict(event) for event in self._history[-300:]],
            "seen_task_ids": self._seen_task_ids[-1000:],
            "max_retries": self._max_retries,
        }
        self._state_file.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def _load_state(self) -> None:
        if not self._state_file.exists():
            return
        try:
            raw = self._state_file.read_text(encoding="utf-8")
            data = json.loads(raw)
        except Exception:
            return

        self._online = bool(data.get("online", True))
        self._max_retries = int(data.get("max_retries", 3) or 3)

        queue_raw = data.get("queue", [])
        rebuilt_queue: list[EdgeTask] = []
        for item in queue_raw:
            try:
                rebuilt_queue.append(
                    EdgeTask(
                        task_id=str(item.get("task_id", "")),
                        action=str(item.get("action", "")),
                        payload=dict(item.get("payload", {})),
                        retry_count=int(item.get("retry_count", 0) or 0),
                        created_at=datetime.fromisoformat(item.get("created_at")) if item.get("created_at") else datetime.utcnow(),
                    )
                )
            except Exception:
                continue
        self._queue = rebuilt_queue

        dead_raw = data.get("dead_letter", [])
        rebuilt_dead: list[dict[str, Any]] = []
        for item in dead_raw:
            if isinstance(item, dict):
                rebuilt_dead.append(dict(item))
        self._dead_letter = rebuilt_dead[-1000:]

        history_raw = data.get("history", [])
        rebuilt_history: list[EdgeEvent] = []
        for item in history_raw:
            try:
                rebuilt_history.append(
                    EdgeEvent(
                        event_type=str(item.get("event_type", "loaded")),
                        detail=dict(item.get("detail", {})),
                        created_at=datetime.fromisoformat(item.get("created_at")) if item.get("created_at") else datetime.utcnow(),
                    )
                )
            except Exception:
                continue
        self._history = rebuilt_history[-500:]

        seen_raw = data.get("seen_task_ids", [])
        self._seen_task_ids = [str(x) for x in seen_raw][-2000:]

    def _execute_task(self, task: EdgeTask) -> tuple[bool, str, dict[str, Any]]:
        # Optional test hook: fail N times before success.
        fail_before_success = int(task.payload.get("_fail_before_success", 0) or 0)
        if task.retry_count < fail_before_success:
            return False, f"simulated_failure_{task.retry_count + 1}", {}

        if self._executor is None:
            return True, "ok", {"note": "no_executor_bound"}

        try:
            result = self._executor(task.action, task.payload)
            return True, "ok", result or {}
        except Exception as exc:
            return False, str(exc), {}

    def _drain_queue(self) -> list[dict[str, Any]]:
        if not self._online or not self._queue:
            return []

        remain: list[EdgeTask] = []
        flushed: list[dict[str, Any]] = []

        for task in self._queue:
            success, reason, exec_result = self._execute_task(task)
            if success:
                self._mark_seen(task.task_id)
                result = {
                    "task_id": task.task_id,
                    "action": task.action,
                    "payload": task.payload,
                    "retry_count": task.retry_count,
                    "executor_result": exec_result,
                    "flushed_at": self._now(),
                }
                flushed.append(result)
                self._log_event("task_flushed", result)
                continue

            task.retry_count += 1
            if task.retry_count > self._max_retries:
                failed_item = {
                    "task_id": task.task_id,
                    "action": task.action,
                    "payload": task.payload,
                    "reason": reason,
                    "retry_count": task.retry_count,
                    "failed_at": self._now(),
                }
                self._dead_letter.append(failed_item)
                if len(self._dead_letter) > 1000:
                    self._dead_letter = self._dead_letter[-1000:]
                self._log_event(
                    "task_failed_final",
                    failed_item,
                )
                continue

            remain.append(task)
            self._log_event(
                "task_retry_scheduled",
                {
                    "task_id": task.task_id,
                    "action": task.action,
                    "payload": task.payload,
                    "reason": reason,
                    "retry_count": task.retry_count,
                },
            )

        self._queue = remain
        return flushed

    def set_network(self, online: bool) -> dict[str, Any]:
        self._online = online
        flushed: list[dict[str, Any]] = []
        if self._online:
            flushed = self._drain_queue()

        self._log_event("network_changed", {"online": self._online, "flushed_count": len(flushed)})
        self._save_state()

        return {
            "online": self._online,
            "queued_count": len(self._queue),
            "flushed": flushed,
        }

    def enqueue_or_execute(self, task_id: str, action: str, payload: dict[str, Any]) -> dict[str, Any]:
        task_id = task_id.strip()
        if not task_id:
            task_id = f"task-{int(datetime.utcnow().timestamp())}"

        if task_id in self._seen_task_ids:
            return {
                "task_id": task_id,
                "mode": "duplicate_ignored",
                "action": action,
                "payload": payload,
                "ignored_at": self._now(),
            }

        for queued in self._queue:
            if queued.task_id == task_id:
                return {
                    "task_id": task_id,
                    "mode": "duplicate_queued",
                    "action": queued.action,
                    "payload": queued.payload,
                    "queued_at": queued.created_at.isoformat(),
                    "queued_count": len(self._queue),
                }

        task = EdgeTask(task_id=task_id, action=action, payload=payload)

        if self._online:
            success, reason, exec_result = self._execute_task(task)
            if success:
                self._mark_seen(task.task_id)
                self._log_event(
                    "task_executed",
                    {
                        "task_id": task.task_id,
                        "action": task.action,
                        "payload": task.payload,
                        "retry_count": task.retry_count,
                        "executor_result": exec_result,
                    },
                )
                self._save_state()
                return {
                    "task_id": task.task_id,
                    "mode": "online_executed",
                    "action": task.action,
                    "payload": task.payload,
                    "executor_result": exec_result,
                    "executed_at": self._now(),
                }

            task.retry_count = 1
            if task.retry_count <= self._max_retries:
                self._queue.append(task)
                self._log_event(
                    "task_retry_scheduled",
                    {
                        "task_id": task.task_id,
                        "action": task.action,
                        "payload": task.payload,
                        "reason": reason,
                        "retry_count": task.retry_count,
                    },
                )
                self._save_state()
                return {
                    "task_id": task.task_id,
                    "mode": "online_failed_queued",
                    "action": task.action,
                    "payload": task.payload,
                    "reason": reason,
                    "retry_count": task.retry_count,
                    "queued_count": len(self._queue),
                }

        self._queue.append(task)
        self._log_event(
            "task_queued",
            {
                "task_id": task.task_id,
                "action": task.action,
                "payload": task.payload,
                "retry_count": task.retry_count,
            },
        )
        self._save_state()
        return {
            "task_id": task.task_id,
            "mode": "offline_queued",
            "action": task.action,
            "payload": task.payload,
            "queued_at": task.created_at.isoformat(),
            "queued_count": len(self._queue),
        }

    def status(self) -> dict[str, Any]:
        return {
            "online": self._online,
            "queued_count": len(self._queue),
            "dead_letter_count": len(self._dead_letter),
            "max_retries": self._max_retries,
            "queue": [self._task_to_dict(item) for item in self._queue],
        }

    def history(self, limit: int = 80) -> dict[str, Any]:
        limit_value = max(1, min(limit, 300))
        items = self._history[-limit_value:]
        return {
            "total": len(self._history),
            "items": [self._event_to_dict(event) for event in items],
        }

    def dead_letter(self, limit: int = 80) -> dict[str, Any]:
        limit_value = max(1, min(limit, 300))
        items = self._dead_letter[-limit_value:]
        return {
            "total": len(self._dead_letter),
            "items": items,
        }

    def requeue_dead_task(self, task_id: str) -> dict[str, Any]:
        for idx, item in enumerate(self._dead_letter):
            if str(item.get("task_id", "")) != task_id:
                continue
            restored = EdgeTask(
                task_id=str(item.get("task_id")),
                action=str(item.get("action", "")),
                payload=dict(item.get("payload", {})),
                retry_count=0,
                created_at=datetime.utcnow(),
            )
            self._queue.insert(0, restored)
            removed = self._dead_letter.pop(idx)
            self._log_event("task_requeued_from_dead_letter", removed)
            self._save_state()
            return {
                "ok": True,
                "task_id": restored.task_id,
                "queued_count": len(self._queue),
                "dead_letter_count": len(self._dead_letter),
            }
        return {
            "ok": False,
            "task_id": task_id,
            "message": "task_not_found_in_dead_letter",
        }

    def drain_now(self) -> dict[str, Any]:
        flushed = self._drain_queue() if self._online else []
        self._save_state()
        return {
            "online": self._online,
            "flushed_count": len(flushed),
            "flushed": flushed,
            "queued_count": len(self._queue),
        }


edge_autonomy_service = EdgeAutonomyService()
