from typing import Annotated, Literal

from pydantic import BaseModel, Field

from schemas.manager import ManagerLoginResponse
from schemas.user import UserLoginResponse


# 앱에서는 계정 종류를 지정하지 않고 공통 필드로 전송합니다.
class LoginRequest(BaseModel):
    login_id: str
    password: str = Field(min_length=1, repr=False)


class AccessTokenResponse(BaseModel):
    access_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int


class UserTokenResponse(UserLoginResponse, AccessTokenResponse):
    pass


class ManagerTokenResponse(ManagerLoginResponse, AccessTokenResponse):
    pass


# 역할별 계정 정보와 access token을 함께 반환합니다.
LoginResponse = Annotated[
    UserTokenResponse | ManagerTokenResponse, Field(discriminator="role")
]


CurrentAccountResponse = Annotated[
    UserLoginResponse | ManagerLoginResponse, Field(discriminator="role")
]
