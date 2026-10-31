from pydantic import BaseModel, ConfigDict, Field, model_validator


class PayCreate(BaseModel):
    # 서버 내부 생성용. 사용자·매니저 ID는 검수 요청에서 조회한다.
    inspection_request_inspection_request_no: str = Field(pattern=r"^[0-9]{14}$")
    model_config = ConfigDict(extra="forbid")


class PayUpdate(BaseModel):
    # 금액은 수량으로 자동 계산하므로 상태만 수정한다.
    model_config = ConfigDict(extra="forbid")

    pay_status: str | None = Field(default=None, min_length=1, max_length=45, pattern=r"\S")

    @model_validator(mode="after")
    def validate_changes(self):
        if not self.model_fields_set:
            raise ValueError("수정할 결제 상태 또는 금액을 입력해주세요.")
        if any(getattr(self, field) is None for field in self.model_fields_set):
            raise ValueError("수정 값은 null일 수 없습니다.")
        return self


class PayResponse(BaseModel):
    pay_no: str
    pay_status: str
    pay_price: int | None = None
    pay_date: str
    user_user_id: str
    manager_manager_id: str
    inspection_request_inspection_request_no: str


class PayCompleteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    expected_price: int = Field(ge=0, le=2147483647, strict=True)
