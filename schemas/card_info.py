from pydantic import BaseModel, ConfigDict, Field


class CardInfoCreate(BaseModel):
    """판매·검수 코드의 기준이 되는 카드 카탈로그 입력값이다."""

    model_config = ConfigDict(extra="forbid")

    cardinfo_serial_code: str = Field(min_length=1, max_length=50, pattern=r"^\S+$")
    cardinfo_category: str = Field(default="카드", min_length=1, max_length=30)
    cardinfo_brand: str = Field(min_length=1, max_length=50)
    cardinfo_standard: str = Field(min_length=1, max_length=100)


class CardInfoResponse(CardInfoCreate):
    # 순번은 사용자가 지정하지 않고 실제 판매·검수 등록 과정에서만 증가한다.
    cardinfo_last_sell_seq: int = 0
    cardinfo_last_inspect_seq: int = 0
