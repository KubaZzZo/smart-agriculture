from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func
from ..database import get_db
from ..models import Zone, ZoneDevice, Device
from ..schemas import ZoneCreate, ZoneResponse, DeviceResponse

router = APIRouter()


def _zone_to_response(zone: Zone, device_count: int) -> dict:
    return {
        "id": zone.id,
        "zone_name": zone.zone_name,
        "zone_type": zone.zone_type,
        "description": zone.description or "",
        "device_count": device_count,
        "is_active": zone.is_active,
        "created_at": zone.created_at,
    }


@router.get("", response_model=list[ZoneResponse])
def list_zones(db: Session = Depends(get_db)):
    zones = db.query(Zone).order_by(Zone.id).all()
    result = []
    for z in zones:
        count = db.query(ZoneDevice).filter(ZoneDevice.zone_id == z.id).count()
        result.append(_zone_to_response(z, count))
    return result


@router.post("", response_model=ZoneResponse)
def create_zone(body: ZoneCreate, db: Session = Depends(get_db)):
    zone = Zone(
        zone_name=body.zone_name,
        zone_type=body.zone_type,
        description=body.description,
        is_active=body.is_active,
    )
    db.add(zone)
    db.commit()
    db.refresh(zone)
    return _zone_to_response(zone, 0)


@router.delete("/{zone_id}")
def delete_zone(zone_id: int, db: Session = Depends(get_db)):
    zone = db.query(Zone).filter(Zone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="区域不存在")
    db.delete(zone)
    db.commit()
    return {"detail": "已删除"}


@router.get("/{zone_id}/devices", response_model=list[DeviceResponse])
def get_zone_devices(zone_id: int, db: Session = Depends(get_db)):
    zone = db.query(Zone).filter(Zone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="区域不存在")
    device_ids = [
        zd.device_id
        for zd in db.query(ZoneDevice).filter(ZoneDevice.zone_id == zone_id).all()
    ]
    if not device_ids:
        return []
    return db.query(Device).filter(Device.id.in_(device_ids)).all()


@router.post("/{zone_id}/devices/{device_id}")
def add_device_to_zone(zone_id: int, device_id: int, db: Session = Depends(get_db)):
    zone = db.query(Zone).filter(Zone.id == zone_id).first()
    if not zone:
        raise HTTPException(status_code=404, detail="区域不存在")
    device = db.query(Device).filter(Device.id == device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail="设备不存在")
    exists = (
        db.query(ZoneDevice)
        .filter(ZoneDevice.zone_id == zone_id, ZoneDevice.device_id == device_id)
        .first()
    )
    if exists:
        return {"detail": "已关联"}
    db.add(ZoneDevice(zone_id=zone_id, device_id=device_id))
    db.commit()
    return {"detail": "关联成功"}


@router.delete("/{zone_id}/devices/{device_id}")
def remove_device_from_zone(zone_id: int, device_id: int, db: Session = Depends(get_db)):
    zd = (
        db.query(ZoneDevice)
        .filter(ZoneDevice.zone_id == zone_id, ZoneDevice.device_id == device_id)
        .first()
    )
    if not zd:
        raise HTTPException(status_code=404, detail="关联不存在")
    db.delete(zd)
    db.commit()
    return {"detail": "已移除"}
