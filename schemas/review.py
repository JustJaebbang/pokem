from pydantic import BaseModel, ConfigDict, Field, field_validator


class ReviewCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    purchase_item_purchase_item_code: str = Field(min_length=1, max_length=45)
    review_rating: int = Field(strict=True, ge=1, le=5)
    review_contents: str = Field(min_length=1, max_length=500)

    @field_validator("review_contents")
    @classmethod
    def nonempty_contents(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("리뷰 내용을 입력해주세요.")
        return value


class ReviewResponse(BaseModel):
    review_code: str
    purchase_item_purchase_item_code: str
    review_contents: str
    review_rating: int
    review_date: str
    user_user_id: str
    sell_product_sell_product_code: str
