from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_account, get_current_manager_only, ensure_manager_self
from schemas.receipt import ReceiptCreate, ReceiptRequest, ReceiptResponse
from services import receipt_service


router = APIRouter(prefix="/receipt", tags=["receipt"])


@router.post("", response_model=ReceiptResponse, status_code=201)
def create_receipt(request: ReceiptRequest, db=Depends(get_db), manager=Depends(get_current_manager_only)):
    manager_id = ensure_manager_self(manager, request.manager_manager_id)
    payload = ReceiptCreate(**{**request.model_dump(), "manager_manager_id": manager_id})
    return receipt_service.create_receipt(db, payload)


@router.get("", response_model=list[ReceiptResponse])
def get_receipts(
    limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
    db=Depends(get_db), current=Depends(get_current_account),
):
    # 사용자는 본인 내역만, 매니저와 director는 전체 내역을 조회한다.
    user_id = current.account.user_id if current.role == "user" else None
    return receipt_service.get_receipts(db, limit, offset, user_id=user_id)


@router.get("/{receipt_no}", response_model=ReceiptResponse)
def get_receipt(
    receipt_no: str = Path(min_length=1, max_length=64),
    db=Depends(get_db), current=Depends(get_current_account),
):
    user_id = current.account.user_id if current.role == "user" else None
    receipt = receipt_service.get_receipt(db, receipt_no, user_id=user_id)
    if receipt is None:
        raise HTTPException(status_code=404, detail="접수 내역을 찾을 수 없습니다.")
    return receipt
