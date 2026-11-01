from pydantic import BaseModel, ConfigDict, Field, model_validator


class CaseCreate(BaseModel):
    # 코드는 서버에서 생성한다. 코드 최대 길이 45자 중 최소 1자는 순번이다.
    model_config = ConfigDict(extra="forbid")

    case_serial_no: str = Field(min_length=1, max_length=44, pattern=r"^\S+$")
    case_price: int | None = Field(default=None, ge=0, le=2147483647, strict=True)
    case_stock: int = Field(default=0, ge=0, le=2147483647, strict=True)


class CaseResponse(BaseModel):
    case_code: str
    case_serial_no: str | None = None
    case_price: int | None = None
    case_stock: int


class CaseUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    case_price: int | None = Field(default=None, ge=0, le=2147483647, strict=True)
    case_stock: int | None = Field(default=None, ge=0, le=2147483647, strict=True)

    @model_validator(mode="after")
    def require_change(self):
        if not self.model_fields_set:
            raise ValueError("수정할 가격 또는 재고를 입력해주세요.")
        return self
