from pydantic import BaseModel


class PostItemResponse(BaseModel):
    post_item_code: str
    sell_product_sell_product_code: str
    user_user_id: str
    post_item_post_date: str
    post_item_complete_date: str | None
    post_item_region: str
