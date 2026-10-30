from pydantic import BaseModel, ConfigDict, Field


class DeliveryCreate(BaseModel):
    # 서비스 입력: 수령자, 배송번호, 날짜, 초기 상태는 서버에서 결정한다.
    model_config = ConfigDict(extra="forbid")

    purchase_item_code: str = Field(min_length=1, max_length=45)
    manager_manager_id: str = Field(min_length=1, max_length=45)
    delivery_company_delivery_company_code: str = Field(min_length=1, max_length=45)


class DeliveryRequest(DeliveryCreate):
    # API 요청에서는 매니저 ID를 생략할 수 있으며 로그인 계정으로 채운다.
    manager_manager_id: str | None = Field(default=None, min_length=1, max_length=45)


class DeliveryResponse(BaseModel):
    purchase_item_code: str
    delivery_no: str
    delivery_date: str | None = None
    delivery_status: str | None = None
    user_user_id: str
    manager_manager_id: str
    delivery_company_delivery_company_code: str
    # 구매자와 상품은 delivery에 중복 저장하지 않고 구매 기록에서 조회한다.
    sell_product_sell_product_code: str
