from pydantic import BaseModel, Field
class PendingActionsResponse(BaseModel):
    fee_count: int = Field(ge=0)
    choice_count: int = Field(ge=0)
    cancel_count: int = Field(ge=0)
    fee_request_no: str | None = None
    choice_request_no: str | None = None
