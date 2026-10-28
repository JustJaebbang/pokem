from pydantic import BaseModel, Field


class InspectionRequestCreate(BaseModel):
    inspection_request_amount: int = Field(gt=0)
    user_user_id: str = Field(min_length=1)


class InspectionRequestManagerUpdate(BaseModel):
    manager_manager_id: str = Field(min_length=1, pattern=r"\S")


class InspectionRequestResponse(BaseModel):
    inspection_request_no: int
    inspection_request_date: str
    inspection_request_amount: int
    user_user_id: str
    manager_manager_id: str | None = None
