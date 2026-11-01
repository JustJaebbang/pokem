from typing import Annotated, Literal

from pydantic import BaseModel, Field


UserProfileImage = Annotated[str, Field(max_length=1000, pattern=r"^/media/products/[0-9a-f]{32}\.(jpg|png|webp)$")]

class UserCreate(BaseModel):
    user_id: str
    user_password: str = Field(min_length=1, repr=False)
    user_nickname: str
    user_name: str
    user_phone: str
    user_email: str
    user_address: str
    user_profile_image: UserProfileImage | None = None


class UserResponse(BaseModel):
    user_id: str
    user_nickname: str
    user_name: str
    user_phone: str
    user_email: str
    user_address: str
    user_money: int
    user_profile_image: str | None = None

# 로그인 응답은 비밀번호를 제외한 사용자 정보만 포함합니다.
class UserLoginResponse(BaseModel):
    role: Literal["user"] = "user"
    account: UserResponse


class UserUpdate(BaseModel):
    user_phone: str
    user_email: str
    user_address: str
    user_profile_image: UserProfileImage | None = None


class UserQuitRequest(BaseModel):
    # 구버전 앱의 탈퇴 요청도 처리하되 새 화면에서는 명시적으로 종류를 선택한다.
    quit_type: Literal["서비스 불만", "이용 빈도 낮음", "개인정보 우려", "다른 서비스 이용", "기타"] = "기타"
    quit_reason: str | None = Field(default=None, max_length=200)


class UserQuitResponse(BaseModel):
    message: str
    user_id: str
    quit_date: str
    quit_type: str
    quit_reason: str | None
