from pydantic import BaseModel, ConfigDict, Field


class ReceiptCreate(BaseModel):
    # 사용자와 번호·날짜는 서버에서 결정한다. DB에 없는 필드는 추가하지 않는다.
    model_config = ConfigDict(extra="forbid")

    pay_pay_no: str = Field(min_length=1, max_length=64, pattern=r"\S")
    receipt_amount: int = Field(gt=0, le=2147483647, strict=True)
    sell_product_sell_product_code: str = Field(min_length=1, max_length=80, pattern=r"\S")
    manager_manager_id: str = Field(min_length=1, max_length=45, pattern=r"\S")


class ReceiptRequest(ReceiptCreate):
    # 생략하면 로그인한 매니저로 채우며 다른 매니저를 지정할 수 없다.
    manager_manager_id: str | None = Field(default=None, min_length=1, max_length=45, pattern=r"\S")


class ReceiptResponse(BaseModel):
    receipt_no: str
    receipt_date: str | None = None
    receipt_amount: int | None = None
    pay_pay_no: str
    user_user_id: str
    manager_manager_id: str
    sell_product_sell_product_code: str
