from pydantic import BaseModel, Field


class ExchangeCreate(BaseModel):
    user_id: str = Field(min_length=1, max_length=20)
    exchange_account: str = Field(min_length=1, max_length=45)
    exchange_price: int = Field(strict=True, gt=0, le=2147483647)


class ExchangeResponse(BaseModel):
    exchange_seq: int
    user_id: str
    exchange_date: str | None
    exchange_account: str | None
    exchange_price: int


class ExchangeCreateResponse(ExchangeResponse):
    message: str
    user_money: int


# 요청의 사용자 ID는 생략 가능하며 서버가 로그인한 사용자로 확정합니다.
class ExchangeRequest(ExchangeCreate):
    user_id: str | None = Field(default=None, min_length=1, max_length=20)
