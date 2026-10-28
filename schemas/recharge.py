from pydantic import BaseModel, Field


class RechargeCreate(BaseModel):
    user_user_id: str = Field(min_length=1, max_length=20)
    recharge_account: str = Field(min_length=1, max_length=45)
    recharge_price: int = Field(strict=True, gt=0, le=2147483647)


class RechargeResponse(BaseModel):
    recharge_seq: int
    user_user_id: str
    recharge_date: str | None
    recharge_account: str | None
    recharge_price: int


class RechargeCreateResponse(RechargeResponse):
    message: str
    user_money: int


# 요청의 사용자 ID는 생략 가능하며 서버가 로그인한 사용자로 확정합니다.
class RechargeRequest(RechargeCreate):
    user_user_id: str | None = Field(default=None, min_length=1, max_length=20)
