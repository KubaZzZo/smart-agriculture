import random
from datetime import datetime
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Device

router = APIRouter()

# 模拟摄像头图片：根据时间段返回不同场景
CAMERA_IMAGES = [
    "farm_morning.jpg",
    "farm_noon.jpg",
    "farm_afternoon.jpg",
    "farm_evening.jpg",
    "farm_night.jpg",
    "farm_cloudy.jpg",
]


def get_scene_image() -> str:
    hour = datetime.now().hour
    if 5 <= hour < 9:
        return CAMERA_IMAGES[0]
    elif 9 <= hour < 13:
        return CAMERA_IMAGES[1]
    elif 13 <= hour < 17:
        return CAMERA_IMAGES[2]
    elif 17 <= hour < 20:
        return CAMERA_IMAGES[3]
    else:
        return CAMERA_IMAGES[4]


@router.get("/snapshot")
def get_snapshot():
    image = get_scene_image()
    return {
        "image_url": f"/static/camera/{image}",
        "timestamp": datetime.now().isoformat(),
    }


@router.get("/status")
def get_camera_status(db: Session = Depends(get_db)):
    camera = db.query(Device).filter(Device.device_type == "camera").first()
    if not camera:
        return {"status": 0, "device_name": "监控摄像头"}
    return {"status": camera.status, "device_name": camera.device_name}
