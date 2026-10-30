from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class DirectorCreate(BaseModel):
    # 실제 DB 컬럼 길이와 NULL 허용 여부에 맞춘 등록 입력이다.
    model_config = ConfigDict(extra="forbid")

    director_id: str = Field(min_length=1, max_length=45, pattern=r"\S")
    director_password: str = Field(min_length=1, repr=False)
    director_name: str | None = Field(default=None, max_length=45)
    director_phone: str | None = Field(default=None, max_length=20)
    director_email: str | None = Field(default=None, max_length=255)
    director_rank: str | None = Field(default=None, max_length=45)


class DirectorResponse(BaseModel):
    # 비밀번호와 해시값은 API 응답에 포함하지 않는다.
    director_id: str
    director_name: str | None = None
    director_phone: str | None = None
    director_email: str | None = None
    director_rank: str | None = None


class DirectorLoginResponse(BaseModel):
    role: Literal["director"] = "director"
    account: DirectorResponse
