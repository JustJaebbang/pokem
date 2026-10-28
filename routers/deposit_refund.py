from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_account, get_current_manager, ensure_account_access, ensure_manager_self
from schemas.deposit_refund import DepositRefundCreate, DepositRefundRequest, DepositRefundResponse
from services import deposit_refund_service

router = APIRouter(prefix="/deposit_refund", tags=["deposit_refund"])


@router.post("", response_model=DepositRefundResponse, status_code=201)
def create_deposit_refund(request: DepositRefundRequest, db=Depends(get_db), manager=Depends(get_current_manager)):
    manager_id = ensure_manager_self(manager, request.manager_manager_id)
    payload = DepositRefundCreate(**{**request.model_dump(), "manager_manager_id": manager_id})
    return deposit_refund_service.create_deposit_refund(db, payload)


@router.get("", response_model=list[DepositRefundResponse])
def get_deposit_refunds(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db=Depends(get_db),
    current=Depends(get_current_account),
):
    user_id = current.account.user_id if current.role == "user" else None
    return deposit_refund_service.get_deposit_refunds(db, limit, offset, user_id=user_id)


@router.get("/{deposit_refund_no}", response_model=DepositRefundResponse)
def get_deposit_refund(
    deposit_refund_no: str = Path(min_length=1, max_length=85),
    user_user_id: str = Query(min_length=1, max_length=20),
    pay_pay_no: str = Query(min_length=1, max_length=64),
    db=Depends(get_db),
    current=Depends(get_current_account),
):
    ensure_account_access(current, user_user_id)
    refund = deposit_refund_service.get_deposit_refund(
        db, deposit_refund_no, user_user_id, pay_pay_no
    )
    if refund is None:
        raise HTTPException(status_code=404, detail="해당 환급 내역을 찾을 수 없습니다.")
    return refund
