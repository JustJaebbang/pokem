from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


class PurchaseCancelCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    purchase_item_purchase_item_code: str = Field(min_length=1, max_length=45)
    purchase_cancel_reason: str = Field(min_length=1, max_length=255)


class PurchaseCancelDecision(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    response_reason: str | None = Field(default=None, max_length=255)


class PurchaseCancelResponse(BaseModel):
    purchase_cancel_code: str
    purchase_item_purchase_item_code: str
    user_user_id: str
    seller_user_id: str
    purchase_cancel_date: str
    purchase_cancel_reason: str
    purchase_cancel_status: Literal["요청중", "승인", "거절", "철회"]
    responded_by_user_id: str | None = None
    responded_at: str | None = None
    response_reason: str | None = None
