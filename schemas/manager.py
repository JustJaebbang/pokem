from pydantic import BaseModel


# 관리자 등록 요청에 필요한 정보입니다.
class ManagerCreate(BaseModel):
    manager_id: str
    manager_password: str
    manager_name: str
    manager_phone: str
    manager_email: str
    manager_dept: str


# 관리자 응답에서는 비밀번호를 제외합니다.
class ManagerResponse(BaseModel):
    manager_id: str
    manager_name: str
    manager_phone: str
    manager_email: str
    manager_dept: str
