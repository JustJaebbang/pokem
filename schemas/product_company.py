from pydantic import BaseModel, ConfigDict, Field


class ProductCompanyCreate(BaseModel):
    # 업체 코드는 직접 입력하며 실제 DB의 컬럼 길이를 초과할 수 없다.
    model_config = ConfigDict(extra="forbid")

    product_company_code: str = Field(min_length=1, max_length=45, pattern=r"\S")
    product_company_name: str | None = Field(default=None, max_length=100)


class ProductCompanyResponse(BaseModel):
    product_company_code: str
    product_company_name: str | None = None
