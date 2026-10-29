from pydantic import BaseModel


class CybermoneyPayResponse(BaseModel):
    cybermoney_pay_code: str
    cybermoney_pay_status: str
    cybermoney_pay_date: str
    cybermoney_pay_price: int
    purchase_item_purchase_item_code: str
    user_user_id: str


class CybermoneyPayCreateResponse(CybermoneyPayResponse):
    message: str
    user_money: int
