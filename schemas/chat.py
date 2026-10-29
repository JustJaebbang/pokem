from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChatCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    chat_type: Literal["text"] = "text"
    chat_contents: str = Field(min_length=1, max_length=500)


class ChatResponse(BaseModel):
    chat_seq: int
    chat_type: str
    chat_contents: str
    chat_time: datetime
    chat_room_chat_room_id: str
    user_user_id: str

    @field_validator("chat_time")
    @classmethod
    def utc_timestamp(cls, value: datetime) -> datetime:
        # DB 세션을 UTC로 설정하므로 드라이버의 naive datetime도 UTC입니다.
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)
