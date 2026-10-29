from fastapi import APIRouter, Depends

from database import get_db
from dependencies import get_current_account, get_current_user
from schemas.purchase_cancel import PurchaseCancelCreate, PurchaseCancelDecision, PurchaseCancelResponse
from services import purchase_cancel_service

router = APIRouter(prefix="/purchase_cancel", tags=["purchase_cancel"])


@router.post("", response_model=PurchaseCancelResponse, status_code=201)
def create_purchase_cancel(request: PurchaseCancelCreate, db=Depends(get_db), user=Depends(get_current_user)):
    return purchase_cancel_service.create_purchase_cancel(db, request, user.user_id)


@router.get("", response_model=list[PurchaseCancelResponse])
def get_purchase_cancel(db=Depends(get_db), current=Depends(get_current_account)):
    return purchase_cancel_service.get_purchase_cancel(db, current)


@router.get("/{cancel_code}", response_model=PurchaseCancelResponse)
def get_purchase_cancel_code(cancel_code: str, db=Depends(get_db), current=Depends(get_current_account)):
    return purchase_cancel_service.get_purchase_cancel(db, current, cancel_code)


@router.post("/{cancel_code}/approve", response_model=PurchaseCancelResponse)
def approve_purchase_cancel(cancel_code: str, decision: PurchaseCancelDecision | None = None, db=Depends(get_db), user=Depends(get_current_user)):
    return purchase_cancel_service.process_purchase_cancel(db, cancel_code, user.user_id, "approve", decision.response_reason if decision else None)


@router.post("/{cancel_code}/reject", response_model=PurchaseCancelResponse)
def reject_purchase_cancel(cancel_code: str, decision: PurchaseCancelDecision | None = None, db=Depends(get_db), user=Depends(get_current_user)):
    return purchase_cancel_service.process_purchase_cancel(db, cancel_code, user.user_id, "reject", decision.response_reason if decision else None)


@router.post("/{cancel_code}/withdraw", response_model=PurchaseCancelResponse)
def withdraw_purchase_cancel(cancel_code: str, db=Depends(get_db), user=Depends(get_current_user)):
    return purchase_cancel_service.process_purchase_cancel(db, cancel_code, user.user_id, "withdraw")
