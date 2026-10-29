from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_manager
from schemas.case import CaseCreate, CaseResponse
from services import case_service

# get_current_manager는 상위 권한인 director도 허용한다.
router = APIRouter(prefix="/case", tags=["case"], dependencies=[Depends(get_current_manager)])


@router.post("", response_model=CaseResponse, status_code=201)
def create_case(request: CaseCreate, db=Depends(get_db)):
    return case_service.create_case(db, request)


@router.get("", response_model=list[CaseResponse])
def get_cases(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db=Depends(get_db),
):
    return case_service.get_cases(db, limit, offset)


@router.get("/{case_code}", response_model=CaseResponse)
def get_case_code(case_code: str = Path(min_length=1, max_length=45), db=Depends(get_db)):
    case = case_service.get_case_code(db, case_code)
    if case is None:
        raise HTTPException(status_code=404, detail="케이스를 찾을 수 없습니다.")
    return case
