from pydantic import BaseModel, ConfigDict, Field
from schemas.sell_product import SellProductResponse


class ConsignCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    inspect_inspect_code: str = Field(min_length=1, max_length=80)
    sell_product_title: str = Field(min_length=1, max_length=100)
    sell_product_image: str = Field(min_length=1, max_length=1000)
    sell_product_contents: str = Field(min_length=1, max_length=500)
    sell_product_sell_price: int = Field(strict=True, gt=0, le=2147483647)
    return_delivery_company_code: str = Field(min_length=1, max_length=45)


class ConsignResponse(BaseModel):
    post_consign_item_code: str
    manager_manager_id: str
    post_consign_item_date: str | None
    post_consign_item_complete_date: str | None
    post_consign_item_intention: str | None
    inspect_inspect_code: str
    sell_product_sell_product_code: str
    user_user_id: str
    post_consign_item_expires_at: str | None = None
    return_delivery_company_code: str | None = None


class ConsignCreateResponse(ConsignResponse):
    sell_product: SellProductResponse


class ConsignReturnCompanyRequest(BaseModel):
    model_config = ConfigDict(extra='forbid')
    return_delivery_company_code: str = Field(min_length=1, max_length=45)
