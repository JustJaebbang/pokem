from typing import Literal
from pydantic import BaseModel

class WalletLedgerResponse(BaseModel):
    event_id: str
    kind: Literal["recharge", "exchange", "payment", "refund", "sale_credit"]
    amount: int
    occurred_at: str | None
    user_user_id: str
    source_code: str
    payment_code: str | None = None
    purchase_code: str | None = None
    product_code: str | None = None
    product_title: str | None = None
