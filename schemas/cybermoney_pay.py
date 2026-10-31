from pydantic import BaseModel


class CybermoneyPayResponse(BaseModel):
    cybermoney_pay_code: str
    cybermoney_pay_status: str
    cybermoney_pay_date: str
    cybermoney_pay_price: int
    purchase_item_purchase_item_code: str
    user_user_id: str
    sell_product_sell_product_code: str | None = None
    sell_product_title: str | None = None
    sell_product_image: str | None = None


class CybermoneyPayCreateResponse(CybermoneyPayResponse):
    message: str
    user_money: int
