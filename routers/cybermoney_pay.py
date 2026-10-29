from fastapi import APIRouter, Depends, HTTPException

from database import get_db
from dependencies import get_current_account, ensure_account_access, resolve_user_id
from schemas.cybermoney_pay import CybermoneyPayResponse
from services import cybermoney_pay_service

router = APIRouter(prefix="/cybermoney_pay", tags=["cybermoney_pay"])


@router.get("", response_model=list[CybermoneyPayResponse])
def get_cybermoney_pay(user_id: str | None = None, db=Depends(get_db), current=Depends(get_current_account)):
    user_id = resolve_user_id(current, user_id)
    return cybermoney_pay_service.get_cybermoney_pay(db, user_id)


@router.get("/{cybermoney_pay_code}", response_model=CybermoneyPayResponse)
def get_cybermoney_pay_code(cybermoney_pay_code: str, db=Depends(get_db), current=Depends(get_current_account)):
    payment = cybermoney_pay_service.get_cybermoney_pay_code(db, cybermoney_pay_code)
    if payment is None:
        raise HTTPException(status_code=404, detail="결제 내역을 찾을 수 없습니다.")
    ensure_account_access(current, payment.user_user_id)
    return payment
