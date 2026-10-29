from fastapi import APIRouter, Depends

from database import get_db
from dependencies import get_current_account, get_current_user, get_current_manager
from schemas.inspection_request import RequestCreate, RequestResponse
from services import inspection_request_service

router = APIRouter(prefix="/inspection_request", tags=["inspection_request"])


@router.post("", response_model=RequestResponse, status_code=201)
def create_request(request: RequestCreate, db=Depends(get_db), user=Depends(get_current_user)):
    return inspection_request_service.create_request(db, request, user.user_id)


@router.get("", response_model=list[RequestResponse])
def get_requests(db=Depends(get_db), current=Depends(get_current_account)):
    return inspection_request_service.get_requests(db, current)


@router.get("/{request_no}", response_model=RequestResponse)
def get_request(request_no: str, db=Depends(get_db), current=Depends(get_current_account)):
    return inspection_request_service.get_requests(db, current, request_no)
