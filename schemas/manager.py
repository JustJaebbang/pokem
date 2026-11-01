from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


class ManagerCreate(BaseModel):
    manager_id: str = Field(min_length=1, max_length=45, pattern=r"\S")
    manager_password: str = Field(min_length=1, repr=False)
    manager_name: str = Field(min_length=1, max_length=45, pattern=r"\S")
    manager_phone: str = Field(min_length=1, max_length=20)
    manager_email: str = Field(min_length=3, max_length=255, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    manager_dept: str = Field(min_length=1, max_length=45, pattern=r"\S")


class ManagerResponse(BaseModel):
    manager_id: str
    manager_name: str
    manager_phone: str
    manager_email: str
    manager_dept: str
    manager_active: bool = True
    manager_updated_at: str | None = None


class ManagerUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    manager_name: str | None = Field(default=None, min_length=1, max_length=45, pattern=r"\S")
    manager_phone: str | None = Field(default=None, min_length=1, max_length=20)
    manager_email: str | None = Field(
        default=None,
        min_length=3,
        max_length=255,
        pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$",
    )
    manager_dept: str | None = Field(default=None, min_length=1, max_length=45, pattern=r"\S")
    manager_active: bool | None = None
    reassign_to_manager_id: str | None = Field(default=None, min_length=1, max_length=45)

    @model_validator(mode="after")
    def require_change(self):
        if not self.model_fields_set:
            raise ValueError("수정할 매니저 정보를 입력해주세요.")
        if self.reassign_to_manager_id is not None and self.manager_active is not False:
            raise ValueError("업무 재배정은 매니저 비활성화와 함께 요청해야 합니다.")
        return self

# 로그인 입력과 응답을 회원 가입 스키마와 분리합니다.
class ManagerLoginResponse(BaseModel):
    role: Literal["manager"] = "manager"
    account: ManagerResponse
