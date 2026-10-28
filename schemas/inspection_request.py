from pydantic import BaseModel


class InspectionRequestResponse(BaseModel):
    inspection_request_no: int
    inspection_request_date: str
    inspection_request_amount: int
    user_user_id: str
    manager_manager_id: str
