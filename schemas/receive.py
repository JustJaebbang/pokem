from pydantic import BaseModel, ConfigDict, Field


class ReceiveCreate(BaseModel):
    # 입고번호·날짜와 제조업체는 서버에서 결정한다.
    model_config = ConfigDict(extra="forbid")

    order_order_no: str = Field(min_length=1, max_length=64, pattern=r"\S")
    receive_price: int = Field(ge=0, le=2147483647, strict=True)
    receive_amount: int = Field(gt=0, le=2147483647, strict=True)
    manager_manager_id: str = Field(min_length=1, max_length=45, pattern=r"\S")


class ReceiveRequest(ReceiveCreate):
    manager_manager_id: str | None = Field(default=None, min_length=1, max_length=45, pattern=r"\S")


class ReceiveResponse(BaseModel):
    receive_no: str
    receive_price: int | None = None
    receive_date: str | None = None
    receive_amount: int | None = None
    order_order_no: str
    manager_manager_id: str
    product_company_product_company_code: str
