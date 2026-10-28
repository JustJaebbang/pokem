from typing import Literal

from pydantic import BaseModel, Field


class UserCreate(BaseModel):
    user_id: str
    user_password: str = Field(min_length=1, repr=False)
    user_nickname: str
    user_name: str
    user_phone: str
    user_email: str
    user_address: str


class UserResponse(BaseModel):
    user_id: str
    user_nickname: str
    user_name: str
    user_phone: str
    user_email: str
    user_address: str
    user_money: int

# 로그인 응답은 비밀번호를 제외한 사용자 정보만 포함합니다.
class UserLoginResponse(BaseModel):
    role: Literal["user"] = "user"
    account: UserResponse


class UserUpdate(BaseModel):
    user_phone: str
    user_email: str
    user_address: str


class UserQuitRequest(BaseModel):
    quit_reason: str | None = Field(default=None, max_length=200)


class UserQuitResponse(BaseModel):
    message: str
    user_id: str
    quit_date: str
    quit_reason: str | None
