from pydantic import BaseModel, ConfigDict, Field


class DepositRefundCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    pay_pay_no: str = Field(min_length=1, max_length=64)
    # 환급 처리자는 결제를 담당했던 매니저와 다를 수 있으므로 따로 입력받는다.
    manager_manager_id: str = Field(min_length=1, max_length=45, pattern=r"\S")


class DepositRefundResponse(BaseModel):
    deposit_refund_no: str
    deposit_refund_price: int | None = None
    deposit_refund_date: str | None = None
    user_user_id: str
    manager_manager_id: str
    pay_pay_no: str


class DepositRefundRequest(DepositRefundCreate):
    manager_manager_id: str | None = Field(default=None, min_length=1, max_length=45, pattern=r"\S")
