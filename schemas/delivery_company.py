from pydantic import BaseModel, ConfigDict, Field


class DeliveryCompanyCreate(BaseModel):
    # 업체 코드는 직접 입력하며 실제 DB의 컬럼 길이를 초과할 수 없다.
    model_config = ConfigDict(extra="forbid")

    delivery_company_code: str = Field(min_length=1, max_length=45, pattern=r"\S")
    delivery_company_name: str | None = Field(default=None, max_length=100)


class DeliveryCompanyResponse(BaseModel):
    delivery_company_code: str
    delivery_company_name: str | None = None
