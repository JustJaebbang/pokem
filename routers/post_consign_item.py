from fastapi import APIRouter, Depends

from database import get_db
from dependencies import get_current_account, get_current_user, get_current_manager
from schemas.post_consign_item import ConsignCreate, ConsignResponse, ConsignCreateResponse, ConsignReturnCompanyRequest
from services import post_consign_item_service

router = APIRouter(prefix="/post_consign_item", tags=["post_consign_item"])


@router.post("", response_model=ConsignCreateResponse, status_code=201)
def create_consign(request: ConsignCreate, db=Depends(get_db), manager=Depends(get_current_manager)):
    return post_consign_item_service.create_consign(db, request, manager.manager_id)


@router.get("", response_model=list[ConsignResponse])
def get_consigns(db=Depends(get_db), current=Depends(get_current_account)):
    return post_consign_item_service.get_consigns(db, current)


@router.get("/{code}", response_model=ConsignResponse)
def get_consign(code: str, db=Depends(get_db), current=Depends(get_current_account)):
    return post_consign_item_service.get_consigns(db, current, code)


@router.patch('/{code}/return-company')
def set_return_company(code: str, request: ConsignReturnCompanyRequest,
                       db=Depends(get_db), manager=Depends(get_current_manager)):
    return post_consign_item_service.set_return_company(db, code, request.return_delivery_company_code)
