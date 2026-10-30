from pydantic import BaseModel


class ProductImageResponse(BaseModel):
    sell_product_image: str
