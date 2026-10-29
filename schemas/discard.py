from pydantic import BaseModel, ConfigDict, Field


class DiscardCreate(BaseModel):
    # DB 기본키는 매니저 ID + 상품 코드이며 폐기일자는 서버에서 생성한다.
    model_config = ConfigDict(extra="forbid")

    sell_product_sell_product_code: str = Field(min_length=1, max_length=80, pattern=r"\S")
    manager_manager_id: str = Field(min_length=1, max_length=45, pattern=r"\S")


class DiscardRequest(DiscardCreate):
    # 생략하면 로그인한 매니저로 채운다. 다른 매니저를 지정할 수 없다.
    manager_manager_id: str | None = Field(default=None, min_length=1, max_length=45, pattern=r"\S")


class DiscardResponse(BaseModel):
    manager_manager_id: str
    discard_date: str | None = None
    sell_product_sell_product_code: str
