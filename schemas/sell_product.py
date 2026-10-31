from pydantic import BaseModel, ConfigDict, Field
from typing import Literal


class SellProductCreate(BaseModel):
    regulation: str
    card_pack_type: str
    element_of_set: str
    set: str
    rarity: str
    sell_product_title: str
    sell_product_image: str
    sell_product_contents: str
    sell_product_sell_price: int
    sell_product_grade: str = 'Unrank'
    # sell_product_sell_status: str = '판매중'


class SellProductResponse(BaseModel):
    seller_user_id: str | None = None
    sale_type: Literal["direct", "consign"] | None = None
    sell_product_code: str
    sell_product_serial_code: str
    seq: int
    sell_product_title: str
    sell_product_image: str
    sell_product_contents: str
    sell_product_sell_price: int
    sell_product_grade: str = 'Unrank'
    sell_product_sell_status: str = '판매중'


class SellProductUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    sell_product_title: str = Field(min_length=1, max_length=100)
    sell_product_image: str = Field(max_length=1000)
    sell_product_contents: str = Field(min_length=1, max_length=500)
    sell_product_sell_price: int = Field(strict=True, gt=0, le=2147483647)


class SellProductDelete(BaseModel):
    message: str
    sell_product_code: str
    sell_product_serial_code: str
    seq: int
    sell_product_title: str
    sell_product_image: str
    sell_product_contents: str
    sell_product_sell_price: int
    sell_product_grade: str = 'Unrank'
    sell_product_sell_status: str = '판매중'