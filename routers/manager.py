from fastapi import APIRouter, Depends, HTTPException

from database import get_db
from dependencies import get_current_manager
from schemas.manager import ManagerCreate, ManagerResponse
from services import manager_service

# 관리자 API의 공통 경로와 Swagger 문서의 그룹 이름입니다.
router = APIRouter(prefix="/manager", tags=["manager"], dependencies=[Depends(get_current_manager)])


# 관리자를 등록합니다.
@router.post("", response_model=ManagerResponse, status_code=201)
def create_manager(manager: ManagerCreate, db=Depends(get_db)):
    return manager_service.create_manager(db, manager)


# 전체 관리자를 조회합니다. 등록된 관리자가 없으면 빈 목록을 반환합니다.
@router.get("", response_model=list[ManagerResponse])
def get_manager(db=Depends(get_db)):
    return manager_service.get_manager(db)


# ID로 관리자를 조회하고, 존재하지 않으면 404를 반환합니다.
@router.get("/{manager_id}", response_model=ManagerResponse)
def get_manager_id(manager_id: str, db=Depends(get_db)):
    manager = manager_service.get_manager_id(db, manager_id)
    if manager is None:
        raise HTTPException(status_code=404, detail="관리자를 찾을 수 없습니다.")
    return manager
