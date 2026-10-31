from typing import Literal
from pydantic import BaseModel

class SaleHistoryResponse(BaseModel):
    sale_code: str
    sale_type: Literal['direct', 'consign']
    product_code: str
    title: str | None = None
    image: str | None = None
    status: str | None = None
    asking_price: int | None = None
    paid_price: int | None = None
    posted_at: str | None = None
    completed_at: str | None = None
