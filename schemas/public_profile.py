from pydantic import BaseModel
class PublicProfileResponse(BaseModel):
    user_id: str
    user_nickname: str
    user_profile_image: str | None = None
    is_withdrawn: bool = False
