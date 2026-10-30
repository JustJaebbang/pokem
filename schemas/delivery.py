from pydantic import BaseModel, ConfigDict, Field, model_validator


class DeliveryCreate(BaseModel):
    # 서비스 입력: 수령자, 배송번호, 날짜, 초기 상태는 서버에서 결정한다.
    model_config = ConfigDict(extra="forbid")

    purchase_item_code: str | None = Field(default=None, min_length=1, max_length=45)
    return_no: str | None = Field(default=None, min_length=1, max_length=64)
    manager_manager_id: str = Field(min_length=1, max_length=45)
    delivery_company_delivery_company_code: str = Field(min_length=1, max_length=45)

    @model_validator(mode="after")
    def validate_source(self):
        # 구매 배송과 반송 배송을 섞거나 원본 없이 등록할 수 없다.
        if (self.purchase_item_code is None) == (self.return_no is None):
            raise ValueError("purchase_item_code와 return_no 중 하나만 지정해주세요.")
        return self


class DeliveryRequest(DeliveryCreate):
    # API 요청에서는 매니저 ID를 생략할 수 있으며 로그인 계정으로 채운다.
    manager_manager_id: str | None = Field(default=None, min_length=1, max_length=45)


class DeliveryResponse(BaseModel):
    purchase_item_code: str | None = None
    return_no: str | None = None
    delivery_no: str
    delivery_date: str | None = None
    delivery_status: str | None = None
    user_user_id: str
    manager_manager_id: str
    delivery_company_delivery_company_code: str
    # 구매 배송은 상품 코드, 반송 배송은 검수 코드를 원본에서 조회한다.
    sell_product_sell_product_code: str | None = None
    inspect_inspect_code: str | None = None
