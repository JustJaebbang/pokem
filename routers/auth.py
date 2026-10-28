from fastapi import APIRouter, Depends

from database import get_db
from schemas.auth import LoginRequest, LoginResponse
from services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


# ID와 비밀번호를 확인해 서버에서 역할을 자동으로 결정합니다.
@router.post("/login", response_model=LoginResponse)
def login(request: LoginRequest, db=Depends(get_db)):
    return auth_service.login(db, request)
