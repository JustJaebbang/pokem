from typing import Literal

from pydantic import BaseModel


class ManagerCreate(BaseModel):
    manager_id: str
    manager_password: str
    manager_name: str
    manager_phone: str
    manager_email: str
    manager_dept: str


class ManagerResponse(BaseModel):
    manager_id: str
    manager_name: str
    manager_phone: str
    manager_email: str
    manager_dept: str

# 로그인 입력과 응답을 회원 가입 스키마와 분리합니다.
class ManagerLoginResponse(BaseModel):
    role: Literal["manager"] = "manager"
    account: ManagerResponse
