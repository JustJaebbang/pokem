from fastapi import APIRouter, Depends, HTTPException, Path

from database import get_db
from schemas.recharge import RechargeCreate, RechargeResponse, RechargeCreateResponse
from services import recharge_service

router = APIRouter(prefix="/recharge", tags=["recharge"])


# 로그인 연결 시 사용자 본인만 충전·조회할 수 있도록 제한합니다.
# 실제 결제 연동 시 결제 승인 확인 후 충전 처리를 실행해야 합니다.
@router.post("", response_model=RechargeCreateResponse, status_code=201)
def create_recharge(recharge: RechargeCreate, db=Depends(get_db)):
    return recharge_service.create_recharge(db, recharge)


@router.get("", response_model=list[RechargeResponse])
def get_recharge(user_id: str, db=Depends(get_db)):
    return recharge_service.get_recharge(db, user_id)


@router.get("/{recharge_seq}", response_model=RechargeResponse)
def get_recharge_seq(recharge_seq: int = Path(gt=0), db=Depends(get_db)):
    recharge = recharge_service.get_recharge_seq(db, recharge_seq)
    if recharge is None:
        raise HTTPException(status_code=404, detail="충전 내역을 찾을 수 없습니다.")
    return recharge
