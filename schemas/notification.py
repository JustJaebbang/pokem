from typing import Literal
from pydantic import BaseModel
class NotificationResponse(BaseModel):
    id: str
    title: str
    body: str
    occurred_at: str | None
    target_type: Literal['inspection_fee','inspection_result','seller_cancel','purchase_cancel','wallet']
    target_code: str | None = None
    user_user_id: str
