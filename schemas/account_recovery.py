from typing import Literal
from pydantic import BaseModel, ConfigDict, Field

class RecoveryRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    purpose: Literal["find_id", "reset_password"]
    email: str = Field(min_length=3, max_length=254, pattern=r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
    user_id: str | None = Field(default=None, min_length=1, max_length=100)

class RecoveryComplete(BaseModel):
    model_config = ConfigDict(extra="forbid")
    challenge_id: str = Field(pattern=r"^[0-9a-f]{32}$")
    code: str = Field(pattern=r"^[0-9]{6}$", repr=False)
    new_password: str | None = Field(default=None, min_length=8, max_length=128, repr=False)

class RecoveryChallenge(BaseModel):
    challenge_id: str
    expires_in: int = 300
    retry_after: int = 60
    message: str = "일치하는 가입 정보가 있으면 이메일로 인증번호를 보냈습니다."

class RecoveryResult(BaseModel):
    user_ids: list[str] = Field(default_factory=list)
    message: str
