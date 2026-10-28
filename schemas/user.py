from pydantic import BaseModel


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