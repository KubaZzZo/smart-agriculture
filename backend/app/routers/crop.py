from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Crop
from ..schemas import CropCreate, CropResponse, CropUpdate

router = APIRouter()

GROWTH_STAGES = ['seedling', 'vegetative', 'flowering', 'fruiting', 'harvest']
STAGE_LABELS = {
    'seedling': 'Seedling',
    'vegetative': 'Vegetative',
    'flowering': 'Flowering',
    'fruiting': 'Fruiting',
    'harvest': 'Harvest',
}


@router.get('', response_model=list[CropResponse])
def list_crops(db: Session = Depends(get_db)):
    return db.query(Crop).order_by(Crop.id.desc()).all()


@router.post('', response_model=CropResponse)
def create_crop(body: CropCreate, db: Session = Depends(get_db)):
    crop = Crop(**body.model_dump())
    db.add(crop)
    db.commit()
    db.refresh(crop)
    return crop


@router.put('/{crop_id}', response_model=CropResponse)
def update_crop(crop_id: int, body: CropUpdate, db: Session = Depends(get_db)):
    crop = db.query(Crop).filter(Crop.id == crop_id).first()
    if not crop:
        raise HTTPException(status_code=404, detail='crop not found')

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(crop, field, value)
    db.commit()
    db.refresh(crop)
    return crop


@router.delete('/{crop_id}')
def delete_crop(crop_id: int, db: Session = Depends(get_db)):
    crop = db.query(Crop).filter(Crop.id == crop_id).first()
    if not crop:
        raise HTTPException(status_code=404, detail='crop not found')

    db.delete(crop)
    db.commit()
    return {'detail': 'crop deleted'}
