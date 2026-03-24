from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import AutomationRule
from ..schemas import (
    AutomationRuleCreate, AutomationRuleUpdate, AutomationRuleResponse,
)

router = APIRouter()


@router.get("/rules", response_model=list[AutomationRuleResponse])
def get_rules(db: Session = Depends(get_db)):
    return db.query(AutomationRule).all()


@router.post("/rules", response_model=AutomationRuleResponse)
def create_rule(req: AutomationRuleCreate, db: Session = Depends(get_db)):
    rule = AutomationRule(**req.model_dump())
    db.add(rule)
    db.commit()
    db.refresh(rule)
    return rule


@router.put("/rules/{rule_id}", response_model=AutomationRuleResponse)
def update_rule(rule_id: int, req: AutomationRuleUpdate, db: Session = Depends(get_db)):
    rule = db.query(AutomationRule).filter(AutomationRule.id == rule_id).first()
    if not rule:
        raise HTTPException(status_code=404, detail="规则不存在")
    for key, value in req.model_dump(exclude_unset=True).items():
        setattr(rule, key, value)
    db.commit()
    db.refresh(rule)
    return rule


@router.delete("/rules/{rule_id}")
def delete_rule(rule_id: int, db: Session = Depends(get_db)):
    rule = db.query(AutomationRule).filter(AutomationRule.id == rule_id).first()
    if not rule:
        raise HTTPException(status_code=404, detail="规则不存在")
    db.delete(rule)
    db.commit()
    return {"message": "删除成功"}
