from fastapi import APIRouter, Depends, HTTPException, Path

from database import get_db
from dependencies import get_current_account, get_current_user, ensure_self, ensure_account_access, resolve_user_id
from schemas.recharge import RechargeCreate, RechargeRequest, RechargeResponse, RechargeCreateResponse
from services import recharge_service

router = APIRouter(prefix="/recharge", tags=["recharge"])


# 본인 계정의 충전만 허용합니다.
# 실제 결제 연동 시 결제 승인 확인 후 충전 처리를 실행해야 합니다.
@router.post("", response_model=RechargeCreateResponse, status_code=201)
def create_recharge(recharge: RechargeRequest, db=Depends(get_db), current_user=Depends(get_current_user)):
    user_id = ensure_self(current_user, recharge.user_user_id)
    recharge = RechargeCreate(**{**recharge.model_dump(), "user_user_id": user_id})
    return recharge_service.create_recharge(db, recharge)


@router.get("", response_model=list[RechargeResponse])
def get_recharge(user_id: str | None = None, db=Depends(get_db), current=Depends(get_current_account)):
    user_id = resolve_user_id(current, user_id)
    return recharge_service.get_recharge(db, user_id)


@router.get("/{recharge_seq}", response_model=RechargeResponse)
def get_recharge_seq(recharge_seq: int = Path(gt=0), db=Depends(get_db), current=Depends(get_current_account)):
    recharge = recharge_service.get_recharge_seq(db, recharge_seq)
    if recharge is None:
        raise HTTPException(status_code=404, detail="충전 내역을 찾을 수 없습니다.")
    ensure_account_access(current, recharge.user_user_id)
    return recharge
