from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_manager_only, ensure_manager_self
from schemas.receive import ReceiveCreate, ReceiveRequest, ReceiveResponse
from services import receive_service


router = APIRouter(prefix="/receive", tags=["receive"], dependencies=[Depends(get_current_manager_only)])


@router.post("", response_model=ReceiveResponse, status_code=201)
def create_receive(request: ReceiveRequest, db=Depends(get_db), manager=Depends(get_current_manager_only)):
    manager_id = ensure_manager_self(manager, request.manager_manager_id)
    payload = ReceiveCreate(**{**request.model_dump(), "manager_manager_id": manager_id})
    return receive_service.create_receive(db, payload)


@router.get("", response_model=list[ReceiveResponse])
def get_receives(
    limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
    db=Depends(get_db), manager=Depends(get_current_manager_only),
):
    return receive_service.get_receives(db, limit, offset, manager_id=manager.manager_id)


@router.get("/{receive_no}", response_model=ReceiveResponse)
def get_receive(
    receive_no: str = Path(min_length=1, max_length=64),
    db=Depends(get_db), manager=Depends(get_current_manager_only),
):
    result = receive_service.get_receive(db, receive_no, manager_id=manager.manager_id)
    if result is None:
        raise HTTPException(status_code=404, detail="입고 내역을 찾을 수 없습니다.")
    return result
