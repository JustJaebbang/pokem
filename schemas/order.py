from pydantic import BaseModel, ConfigDict, Field


class OrderCreate(BaseModel):
    # 품의에 연결된 케이스와 주문번호·날짜는 서버에서 결정한다.
    model_config = ConfigDict(extra="forbid")

    proposal_proposal_no: str = Field(min_length=1, max_length=64, pattern=r"\S")
    order_price: int = Field(ge=0, le=2147483647, strict=True)
    order_amount: int = Field(gt=0, le=2147483647, strict=True)
    manager_manager_id: str = Field(min_length=1, max_length=45, pattern=r"\S")
    product_company_product_company_code: str = Field(min_length=1, max_length=45, pattern=r"\S")


class OrderRequest(OrderCreate):
    # 생략하면 로그인한 매니저 ID를 사용하며 다른 매니저는 지정할 수 없다.
    manager_manager_id: str | None = Field(default=None, min_length=1, max_length=45, pattern=r"\S")


class OrderResponse(BaseModel):
    order_no: str
    order_price: int | None = None
    order_date: str | None = None
    order_amount: int | None = None
    proposal_proposal_no: str
    case_case_code: str
    manager_manager_id: str
    product_company_product_company_code: str
