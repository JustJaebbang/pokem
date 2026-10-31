from fastapi import APIRouter, Depends

from database import get_db
from dependencies import get_current_account, get_current_user, get_current_manager
from schemas.inspect import InspectCreate, InspectComplete, InspectChoice, InspectResponse, InspectUserResponse
from services import inspect_service

router = APIRouter(prefix="/inspect", tags=["inspect"])


@router.post("", response_model=InspectResponse, status_code=201)
def create_inspect(item: InspectCreate, db=Depends(get_db), manager=Depends(get_current_manager)):
    return inspect_service.create_inspect(db, item, manager.manager_id)


@router.get("", response_model=list[InspectResponse | InspectUserResponse])
def get_inspects(request_no: str | None=None, db=Depends(get_db), current=Depends(get_current_account)):
    results = inspect_service.get_inspects(db, current, request_no=request_no)
    return [_for_viewer(item, current) for item in results]


@router.get("/{inspect_code}", response_model=InspectResponse | InspectUserResponse)
def get_inspect(inspect_code: str, db=Depends(get_db), current=Depends(get_current_account)):
    result = inspect_service.get_inspects(db, current, inspect_code=inspect_code)
    return _for_viewer(result, current)


@router.post("/{inspect_code}/start", response_model=InspectResponse)
def start_inspect(inspect_code: str, db=Depends(get_db), manager=Depends(get_current_manager)):
    return inspect_service.transition_inspect(db, inspect_code, manager.manager_id)


@router.post("/{inspect_code}/complete", response_model=InspectResponse)
def complete_inspect(inspect_code: str, result: InspectComplete, db=Depends(get_db), manager=Depends(get_current_manager)):
    return inspect_service.transition_inspect(db, inspect_code, manager.manager_id, result)


@router.put("/{inspect_code}/choice", response_model=InspectUserResponse)
def choose_inspect(inspect_code: str, choice: InspectChoice, db=Depends(get_db), user=Depends(get_current_user)):
    return inspect_service.choose_inspect(db, inspect_code, choice, user.user_id)


def _for_viewer(item, current):
    if current.role == "user":
        return InspectUserResponse.model_validate(item.model_dump())
    return item
