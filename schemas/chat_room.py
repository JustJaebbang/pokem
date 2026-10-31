from pydantic import BaseModel, ConfigDict, Field


class ChatRoomCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    sell_product_sell_product_code: str = Field(min_length=1, max_length=80)


class ChatRoomResponse(BaseModel):
    chat_room_id: str
    chat_room_name: str | None
    chat_room_status: str
    chat_room_date: str
    sell_product_sell_product_code: str
    inquirer_user_id: str
    seller_user_id: str

    other_user_nickname: str | None = None
    other_user_profile_image: str | None = None
    other_user_withdrawn: bool = False
