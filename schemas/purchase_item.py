from pydantic import BaseModel, Field


class PurchaseItemCreate(BaseModel):
    user_user_id: str = Field(min_length=1, max_length=20)
    expected_price: int | None = Field(default=None, strict=True, ge=0, le=2147483647)
    sell_product_sell_product_code: str = Field(min_length=1, max_length=80)


class PurchaseItemResponse(BaseModel):
    purchase_item_code: str
    user_user_id: str
    purchase_item_date: str | None
    purchase_item_status: str = "거래중"
    purchase_item_confirmed_at: str | None = None
    sell_product_sell_product_code: str


class PurchaseItemDetailResponse(PurchaseItemResponse):
    sell_product_title: str | None = None
    sell_product_image: str | None = None
    # 판매가가 아닌 해당 구매 건의 실제 결제 금액입니다.
    cybermoney_pay_price: int | None = None


# 요청의 사용자 ID는 생략 가능하며 서버가 로그인한 사용자로 확정합니다.
class PurchaseItemRequest(PurchaseItemCreate):
    user_user_id: str | None = Field(default=None, min_length=1, max_length=20)


class PurchaseItemConfirmResponse(BaseModel):
    message: str
    purchase_item_code: str
    sell_product_code: str
    seller_user_id: str
    cybermoney_pay_code: str
    cybermoney_give_code: str
    cybermoney_give_price: int
    post_item_complete_date: str
    sell_product_sell_status: str
