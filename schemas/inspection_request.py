from inspection_pricing import MAX_INSPECTION_AMOUNT
from pydantic import BaseModel, ConfigDict, Field


class InspectionRequestCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    inspection_request_amount: int = Field(strict=True, gt=0, le=MAX_INSPECTION_AMOUNT)
    user_user_id: str = Field(min_length=1)


class InspectionRequestManagerUpdate(BaseModel):
    manager_manager_id: str = Field(min_length=1, pattern=r"\S")
    model_config = ConfigDict(extra="forbid")


class InspectionRequestResponse(BaseModel):
    inspection_request_no: str
    inspection_request_date: str | None
    inspection_request_amount: int | None
    user_user_id: str
    manager_manager_id: str | None = None


class InspectionPricingResponse(BaseModel):
    # 단가 변경 시각도 프로젝트 날짜 정책에 맞춰 VARCHAR 문자열로 전달한다.
    inspection_unit_price: int
    updated_at: str


class InspectionRequestCreateRequest(InspectionRequestCreate):
    user_user_id: str | None = Field(default=None, min_length=1)


class InspectionRequestManagerRequest(InspectionRequestManagerUpdate):
    manager_manager_id: str | None = Field(default=None, min_length=1, pattern=r"\S")


# 갱신 코드의 기존 호출과 호환한다.
RequestCreate = InspectionRequestCreateRequest
RequestResponse = InspectionRequestResponse
