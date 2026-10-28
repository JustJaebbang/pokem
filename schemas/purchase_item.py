from pydantic import BaseModel, Field


class PurchaseItemCreate(BaseModel):
    user_user_id: str = Field(min_length=1, max_length=20)
    sell_product_sell_product_code: str = Field(min_length=1, max_length=80)


class PurchaseItemResponse(BaseModel):
    purchase_item_code: str
    user_user_id: str
    purchase_item_date: str | None
    sell_product_sell_product_code: str


# 요청의 사용자 ID는 생략 가능하며 서버가 로그인한 사용자로 확정합니다.
class PurchaseItemRequest(PurchaseItemCreate):
    user_user_id: str | None = Field(default=None, min_length=1, max_length=20)
