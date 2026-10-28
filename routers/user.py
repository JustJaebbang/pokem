from fastapi import APIRouter, Depends, HTTPException

from database import get_db
from dependencies import get_current_account, get_current_user, get_current_manager, ensure_self, ensure_account_access

from schemas.user import UserCreate, UserResponse, UserUpdate, UserQuitRequest, UserQuitResponse
from services import user_service

router = APIRouter(prefix="/user", tags=["user"])

# user 입력
@router.post("", response_model=UserResponse, status_code=201)
def create_user(user: UserCreate, db=Depends(get_db)):
    return user_service.create_user(db, user)


# 모든 user 가져오기
@router.get("", response_model=list[UserResponse])
def get_user(db=Depends(get_db), manager=Depends(get_current_manager)):
    user = user_service.get_user(db)
    if user is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    return user


# user_id로 해당 user 가져오기
@router.get("/{user_id}", response_model=UserResponse)
def get_user_id(user_id: str, db=Depends(get_db), current=Depends(get_current_account)):
    ensure_account_access(current, user_id)
    user = user_service.get_user_id(db, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    return user


# user_id에 해당하는 사용자 정보 변경
@router.put("/{user_id}", response_model=UserResponse)
def put_user_id(user: UserUpdate, user_id: str, db=Depends(get_db), current_user=Depends(get_current_user)):
    user_id = ensure_self(current_user, user_id)
    updated_user = user_service.put_user_id(db, user, user_id)
    if updated_user is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    return updated_user


# 본인 계정만 탈퇴할 수 있습니다.
@router.delete("/{user_id}", response_model=UserQuitResponse)
def delete_user_id(user_id: str, quit: UserQuitRequest, db=Depends(get_db), current_user=Depends(get_current_user)):
    user_id = ensure_self(current_user, user_id)
    result = user_service.delete_user_id(db, quit, user_id)
    if result is None:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
    return result
