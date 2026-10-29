from pydantic import BaseModel, ConfigDict, Field


class RequestCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    inspection_request_amount: int = Field(strict=True, gt=0, le=2147483647)


class RequestResponse(BaseModel):
    inspection_request_no: str
    inspection_request_date: str | None
    inspection_request_amount: int | None
    user_user_id: str
    manager_manager_id: str | None
