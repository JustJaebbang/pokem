from typing import Literal
from fastapi import APIRouter, Depends, Query
from database import get_db
from dependencies import get_current_user
from schemas.wallet_ledger import WalletLedgerResponse
from services.wallet_ledger_service import get_wallet_ledger

router = APIRouter(prefix="/wallet", tags=["wallet"])

@router.get("/transactions", response_model=list[WalletLedgerResponse])
def get_transactions(
    limit: int = Query(default=30, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    direction: Literal["in", "out"] | None = None,
    db=Depends(get_db), user=Depends(get_current_user),
):
    return get_wallet_ledger(db, user.user_id, limit, offset, direction)
