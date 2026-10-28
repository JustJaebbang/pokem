from pydantic import BaseModel, Field


class WishlistCreate(BaseModel):
    user_user_id: str = Field(min_length=1, max_length=20)
    sell_product_sell_product_code: str = Field(min_length=1, max_length=80)


class WishlistResponse(BaseModel):
    wishlist_seq: int
    wishlist_date: str | None
    wishlist_status: str
    wishlist_update: str | None
    user_user_id: str
    sell_product_sell_product_code: str


# 요청의 사용자 ID는 생략 가능하며 서버가 로그인한 사용자로 확정합니다.
class WishlistRequest(WishlistCreate):
    user_user_id: str | None = Field(default=None, min_length=1, max_length=20)
