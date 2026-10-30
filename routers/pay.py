from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_account, get_current_manager, ensure_account_access
from schemas.pay import PayResponse, PayUpdate
from services import pay_service

router = APIRouter(prefix="/pay", tags=["pay"])


# 결제는 검수 요청 확인 시 생성하므로 별도 POST는 제공하지 않는다.
@router.get("", response_model=list[PayResponse])
def get_pays(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    request_no: str | None = Query(default=None, pattern=r"^[0-9]{14}$"),
    db=Depends(get_db),
    current=Depends(get_current_account),
):
    user_id = current.account.user_id if current.role == "user" else None
    return pay_service.get_pays(db, limit, offset, user_id=user_id, request_no=request_no)


@router.get("/{pay_no}", response_model=PayResponse)
def get_pay(pay_no: str = Path(min_length=1, max_length=64), db=Depends(get_db), current=Depends(get_current_account)):
    pay = pay_service.get_pay(db, pay_no)
    if pay is None:
        raise HTTPException(status_code=404, detail="해당 결제를 찾을 수 없습니다.")
    ensure_account_access(current, pay.user_user_id)
    return pay


@router.patch("/{pay_no}", response_model=PayResponse)
def update_pay(
    request: PayUpdate,
    pay_no: str = Path(min_length=1, max_length=64),
    db=Depends(get_db),
    manager=Depends(get_current_manager),
):
    return pay_service.update_pay(db, pay_no, request)
