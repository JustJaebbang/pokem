from fastapi import APIRouter, Depends, HTTPException, Path

from database import get_db
from schemas.inspection_request import (
    InspectionRequestCreate,
    InspectionRequestManagerUpdate,
    InspectionRequestResponse,
)
from services import inspection_request_service

router = APIRouter(prefix="/inspection_request", tags=["inspection_request"])


# 검수 요청 생성: 번호 발급과 DB 저장은 service에서 처리한다.
@router.post("", response_model=InspectionRequestResponse, status_code=201)
def create_inspection_request(request: InspectionRequestCreate, db=Depends(get_db)):
    return inspection_request_service.create_inspection_request(db, request)


# 전체 검수 요청 조회. 등록된 요청이 없으면 빈 목록을 반환한다.
@router.get("", response_model=list[InspectionRequestResponse])
def get_inspection_requests(db=Depends(get_db)):
    return inspection_request_service.get_inspection_requests(db)


# 양수인 요청 번호만 허용하며, 조회 결과가 없으면 404를 반환한다.
@router.get("/{inspection_request_no}", response_model=InspectionRequestResponse)
def get_inspection_request(
    inspection_request_no: str = Path(pattern=r"^[0-9]{14}$"), db=Depends(get_db)
):
    request = inspection_request_service.get_inspection_request(db, inspection_request_no)
    if request is None:
        raise HTTPException(status_code=404, detail="해당 검수 요청을 찾을 수 없습니다.")
    return request


# 담당자가 없는 요청에만 매니저를 배정한다.
@router.patch("/{inspection_request_no}/manager", response_model=InspectionRequestResponse)
def assign_inspection_request_manager(
    request: InspectionRequestManagerUpdate,
    inspection_request_no: str = Path(pattern=r"^[0-9]{14}$"),
    db=Depends(get_db),
):
    return inspection_request_service.assign_inspection_request_manager(
        db, inspection_request_no, request
    )
