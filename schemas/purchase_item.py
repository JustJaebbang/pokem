from pydantic import BaseModel, Field


class PurchaseItemCreate(BaseModel):
    user_user_id: str = Field(min_length=1, max_length=20)
    sell_product_sell_product_code: str = Field(min_length=1, max_length=80)


class PurchaseItemResponse(BaseModel):
    purchase_item_code: str
    user_user_id: str
    purchase_item_date: str | None
    sell_product_sell_product_code: str
