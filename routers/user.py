from fastapi import APIRouter, Depends, HTTPException

from database import get_db

from schemas.user import UserCreate, UserResponse
from services import user_service

router = APIRouter(prefix="/user", tags=["user"])


# user 입력
@router.post("", response_model=UserResponse, status_code=201)
def create_user(user: UserCreate, db=Depends(get_db)):
    return user_service.create_user(db, user)

# 모든 user 가져오기
@router.get("", response_model=list[UserResponse])
def get_user(db=Depends(get_db)):
    user = user_service.get_user(db)
    if user is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    return user

# user_id로 해당 user 가져오기
@router.get("/{user_id}", response_model=UserResponse)
def get_user_id(user_id: str, db=Depends(get_db)):
    user = user_service.get_user_id(db, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    return user
