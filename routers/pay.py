from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_account, get_current_user, get_current_manager, ensure_account_access
from schemas.pay import PayResponse, PayUpdate, PayCompleteRequest
from services import pay_service

router = APIRouter(prefix="/pay", tags=["pay"])


# 결제 건은 검수 요청 확인 시 생성한다. 사용자 완료 처리는 아래 별도 경로를 사용한다.
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


@router.post("/{pay_no}/complete", response_model=PayResponse)
def complete_pay(request: PayCompleteRequest, pay_no: str = Path(min_length=1, max_length=64),
                 db=Depends(get_db), user=Depends(get_current_user)):
    return pay_service.complete_pay(db, pay_no, user.user_id, request.expected_price)
