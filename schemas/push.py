from pydantic import BaseModel, ConfigDict, Field

class PushDeviceRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    fid: str = Field(min_length=20, max_length=4096, repr=False, pattern=r"^\S+$")

class PushDeviceResult(BaseModel):
    registered: bool
