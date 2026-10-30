from pydantic import BaseModel, ConfigDict, Field


class InspectionRequestCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    inspection_request_amount: int = Field(strict=True, gt=0, le=2147483647)
    user_user_id: str = Field(min_length=1)


class InspectionRequestManagerUpdate(BaseModel):
    manager_manager_id: str = Field(min_length=1, pattern=r"\S")
    # 매니저가 확정한 총 결제 금액. DB INT 범위 안의 원 단위 정수만 받는다.
    pay_price: int = Field(ge=0, le=2147483647, strict=True)


class InspectionRequestResponse(BaseModel):
    inspection_request_no: str
    inspection_request_date: str | None
    inspection_request_amount: int | None
    user_user_id: str
    manager_manager_id: str | None = None


class InspectionRequestCreateRequest(InspectionRequestCreate):
    user_user_id: str | None = Field(default=None, min_length=1)


class InspectionRequestManagerRequest(InspectionRequestManagerUpdate):
    manager_manager_id: str | None = Field(default=None, min_length=1, pattern=r"\S")


# 갱신 코드의 기존 호출과 호환한다.
RequestCreate = InspectionRequestCreateRequest
RequestResponse = InspectionRequestResponse
