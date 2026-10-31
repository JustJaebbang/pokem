from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


class InspectCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    inspect_requested_no: str = Field(min_length=1, max_length=14)
    inspect_serial_code: str = Field(min_length=1, max_length=50)


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
