from pydantic import BaseModel, ConfigDict, Field


class ReturnManagerRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    manager_manager_id: str | None = Field(default=None, min_length=1, max_length=45)


class ReturnResponse(BaseModel):
    return_no: str
    inspect_inspect_code: str
    user_user_id: str
    manager_manager_id: str | None
