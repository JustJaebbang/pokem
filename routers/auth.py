from fastapi import APIRouter, Depends, Response

from database import get_db
from schemas.auth import LoginRequest, LoginResponse, CurrentAccountResponse
from dependencies import get_current_account
from services import auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


# ID와 비밀번호를 확인해 역할별 access token을 발급합니다.
@router.post("/login", response_model=LoginResponse)
def login(request: LoginRequest, response: Response, db=Depends(get_db)):
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    return auth_service.login(db, request)


@router.get("/me", response_model=CurrentAccountResponse)
def get_me(response: Response, current=Depends(get_current_account)):
    response.headers["Cache-Control"] = "no-store"
    return current
