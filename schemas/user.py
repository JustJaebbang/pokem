from typing import Literal

from pydantic import BaseModel


class UserCreate(BaseModel):
    user_id: str
    user_password: str
    user_nickname: str
    user_name: str
    user_phone: str
    user_email: str
    user_address: str
    user_money: int = 0


class UserResponse(BaseModel):
    user_id: str
    user_nickname: str
    user_name: str
    user_phone: str
    user_email: str
    user_address: str
    user_money: int


# 로그인 입력과 응답을 회원 가입 스키마와 분리합니다.
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
