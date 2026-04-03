from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import AutomationRule, Device
from ..schemas import AutomationRuleCreate, AutomationRuleResponse, AutomationRuleUpdate

router = APIRouter()


@router.get('/rules', response_model=list[AutomationRuleResponse])
def get_rules(db: Session = Depends(get_db)):
    return db.query(AutomationRule).all()


@router.post('/rules', response_model=AutomationRuleResponse)
def create_rule(req: AutomationRuleCreate, db: Session = Depends(get_db)):
    device = db.query(Device).filter(Device.id == req.action_device_id).first()
    if not device:
        raise HTTPException(status_code=404, detail='action device not found')

    rule = AutomationRule(**req.model_dump())
    try:
        db.add(rule)
        db.commit()
        db.refresh(rule)
        return rule
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail='invalid automation rule')


@router.put('/rules/{rule_id}', response_model=AutomationRuleResponse)
def update_rule(rule_id: int, req: AutomationRuleUpdate, db: Session = Depends(get_db)):
    rule = db.query(AutomationRule).filter(AutomationRule.id == rule_id).first()
    if not rule:
        raise HTTPException(status_code=404, detail='rule not found')

    payload = req.model_dump(exclude_unset=True)
    if 'action_device_id' in payload:
        device = db.query(Device).filter(Device.id == payload['action_device_id']).first()
        if not device:
            raise HTTPException(status_code=404, detail='action device not found')

    for key, value in payload.items():
        setattr(rule, key, value)

    try:
        db.commit()
        db.refresh(rule)
        return rule
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=400, detail='invalid automation rule')


@router.delete('/rules/{rule_id}')
def delete_rule(rule_id: int, db: Session = Depends(get_db)):
    rule = db.query(AutomationRule).filter(AutomationRule.id == rule_id).first()
    if not rule:
        raise HTTPException(status_code=404, detail='rule not found')

    db.delete(rule)
    db.commit()
    return {'message': 'deleted'}
