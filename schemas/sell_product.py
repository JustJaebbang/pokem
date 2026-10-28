from pydantic import BaseModel


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
    sell_product_sell_status: str = '판매중'


class SellProductResponse(BaseModel):
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
    sell_product_title: str
    sell_product_image: str
    sell_product_contents: str
    sell_product_sell_price: int


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