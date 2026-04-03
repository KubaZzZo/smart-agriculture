from __future__ import annotations

from typing import Any

from ..database import SessionLocal
from ..models import Device, DeviceLog


def _device_to_dict(device: Device) -> dict[str, Any]:
    return {
        "device_id": int(device.id),
        "device_name": str(device.device_name),
        "device_type": str(device.device_type),
        "status": int(device.status),
        "params": dict(device.params or {}),
    }


def execute_edge_task(action: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Execute an edge task against real device tables.

    Supported actions:
    - device_control: {device_id|device_type, status, mode?}
    - device_params: {device_id, params}
    - incident_step: bookkeeping only
    """
    db = SessionLocal()
    try:
        if action == "incident_step":
            return {
                "accepted": True,
                "action": action,
                "detail": payload,
            }

        if action == "device_params":
            device_id = payload.get("device_id")
            params = payload.get("params")
            if not isinstance(device_id, int):
                raise ValueError("device_params requires integer device_id")
            if not isinstance(params, dict):
                raise ValueError("device_params requires object params")

            device = db.query(Device).filter(Device.id == device_id).first()
            if not device:
                raise ValueError(f"device_id {device_id} not found")

            merged = dict(device.params or {})
            merged.update(params)
            device.params = merged
            db.add(
                DeviceLog(
                    device_id=device.id,
                    action="set",
                    params={"edge_payload": payload},
                    source="edge_ai",
                )
            )
            db.commit()
            db.refresh(device)
            return {
                "updated": [_device_to_dict(device)],
                "count": 1,
            }

        if action == "device_control":
            raw_status = payload.get("status")
            if raw_status not in (0, 1, "0", "1"):
                raise ValueError("device_control requires status in {0,1}")
            status = int(raw_status)
            mode = payload.get("mode")

            devices: list[Device] = []
            if isinstance(payload.get("device_id"), int):
                device_id = int(payload["device_id"])
                one = db.query(Device).filter(Device.id == device_id).first()
                if one:
                    devices = [one]
            elif isinstance(payload.get("device_type"), str):
                device_type = str(payload["device_type"])
                devices = db.query(Device).filter(Device.device_type == device_type).all()

            if not devices:
                raise ValueError("no matched device for control")

            action_name = "on" if status == 1 else "off"
            updated: list[dict[str, Any]] = []
            for device in devices:
                device.status = status
                if isinstance(mode, str) and mode:
                    merged = dict(device.params or {})
                    merged["mode"] = mode
                    device.params = merged

                db.add(
                    DeviceLog(
                        device_id=device.id,
                        action=action_name,
                        params={"edge_payload": payload},
                        source="edge_ai",
                    )
                )
                updated.append(_device_to_dict(device))

            db.commit()
            return {
                "updated": updated,
                "count": len(updated),
            }

        raise ValueError(f"unsupported action: {action}")
    finally:
        db.close()
