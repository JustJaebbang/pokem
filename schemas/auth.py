from typing import Annotated

from pydantic import BaseModel, Field

from schemas.manager import ManagerLoginResponse
from schemas.user import UserLoginResponse


# 앱에서는 계정 종류를 지정하지 않고 공통 필드로 전송합니다.
class LoginRequest(BaseModel):
    login_id: str
    password: str


# role에 따라 사용자 또는 관리자 계정 형식으로 응답합니다.
LoginResponse = Annotated[
    UserLoginResponse | ManagerLoginResponse, Field(discriminator="role")
]
