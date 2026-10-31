from fastapi import APIRouter, Depends, Path, Query

from database import get_db
from dependencies import get_current_account, get_current_manager, ensure_manager_self
from schemas.return_item import ReturnManagerRequest, ReturnResponse
from services import return_service

router = APIRouter(prefix="/return", tags=["return"])


@router.get("", response_model=list[ReturnResponse])
def get_returns(limit: int = Query(default=20, ge=1, le=100),
                offset: int = Query(default=0, ge=0),
                inspect_code: str | None = Query(default=None, min_length=1, max_length=80),
                db=Depends(get_db), current=Depends(get_current_account)):
    user_id = current.account.user_id if current.role == "user" else None
    return return_service.get_returns(db, user_id=user_id, limit=limit, offset=offset, inspect_code=inspect_code)


@router.get("/{return_no}", response_model=ReturnResponse)
def get_return(return_no: str = Path(min_length=1, max_length=64),
               db=Depends(get_db), current=Depends(get_current_account)):
    user_id = current.account.user_id if current.role == "user" else None
    return return_service.get_return(db, return_no, user_id=user_id)


@router.patch("/{return_no}/manager", response_model=ReturnResponse)
def assign_manager(request: ReturnManagerRequest,
                   return_no: str = Path(min_length=1, max_length=64),
                   db=Depends(get_db), manager=Depends(get_current_manager)):
    manager_id = ensure_manager_self(manager, request.manager_manager_id)
    return return_service.assign_manager(db, return_no, manager_id)

