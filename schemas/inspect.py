from typing import Literal
from pydantic import BaseModel, ConfigDict, Field, model_validator


class InspectCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    inspect_requested_no: str = Field(min_length=1, max_length=14)
    inspect_serial_code: str = Field(min_length=1, max_length=50)
    inspect_grade: str | None = Field(default=None, min_length=1, max_length=20)
    inspect_grade_reason: str | None = Field(default=None, min_length=1, max_length=200)

    @model_validator(mode="after")
    def validate_result_pair(self):
        if (self.inspect_grade is None) != (self.inspect_grade_reason is None):
            raise ValueError("inspect_grade와 inspect_grade_reason은 함께 입력해야 합니다.")
        return self


class InspectComplete(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    inspect_grade: str = Field(min_length=1, max_length=20)
    inspect_grade_reason: str = Field(min_length=1, max_length=200)


class InspectChoice(BaseModel):
    model_config = ConfigDict(extra="forbid")
    inspect_user_choice: Literal["반환", "대리판매"]


class InspectUserResponse(BaseModel):
    inspect_code: str
    inspect_serial_code: str
    seq: int
    inspect_requested_no: str
    inspect_status: str
    inspect_date: str | None
    inspect_grade: str | None
    inspect_user_choice: str | None
    inspect_user_choice_at: str | None
    manager_manager_id: str | None
    user_user_id: str


class InspectResponse(InspectUserResponse):
    inspect_grade_reason: str | None
