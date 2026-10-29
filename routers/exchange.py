from fastapi import APIRouter, Depends, HTTPException, Path

from database import get_db
from dependencies import get_current_account, get_current_user, ensure_self, ensure_account_access, resolve_user_id
from schemas.exchange import ExchangeCreate, ExchangeRequest, ExchangeResponse, ExchangeCreateResponse
from services import exchange_service

router = APIRouter(prefix="/exchange", tags=["exchange"])


# 본인 계정의 환전만 허용
# 실제 은행 송금은 구현하지 않음
@router.post("", response_model=ExchangeCreateResponse, status_code=201)
def create_exchange(exchange: ExchangeRequest, db=Depends(get_db), current_user=Depends(get_current_user)):
    user_id = ensure_self(current_user, exchange.user_id)
    exchange = ExchangeCreate(**{**exchange.model_dump(), "user_id": user_id})
    return exchange_service.create_exchange(db, exchange)


@router.get("", response_model=list[ExchangeResponse])
def get_exchange(user_id: str | None = None, db=Depends(get_db), current=Depends(get_current_account)):
    user_id = resolve_user_id(current, user_id)
    return exchange_service.get_exchange(db, user_id)


@router.get("/{exchange_seq}", response_model=ExchangeResponse)
def get_exchange_seq(exchange_seq: int = Path(gt=0), db=Depends(get_db), current=Depends(get_current_account)):
    exchange = exchange_service.get_exchange_seq(db, exchange_seq)
    if exchange is None:
        raise HTTPException(status_code=404, detail="환전 내역을 찾을 수 없습니다.")
    ensure_account_access(current, exchange.user_id)
    return exchange
