from pydantic import BaseModel, Field


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
