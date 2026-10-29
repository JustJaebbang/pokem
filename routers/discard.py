from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_manager, get_current_manager_only, ensure_manager_self
from schemas.discard import DiscardCreate, DiscardRequest, DiscardResponse
from services import discard_service


router = APIRouter(prefix="/discard", tags=["discard"], dependencies=[Depends(get_current_manager)])


@router.post("", response_model=DiscardResponse, status_code=201)
def create_discard(request: DiscardRequest, db=Depends(get_db), manager=Depends(get_current_manager_only)):
    manager_id = ensure_manager_self(manager, request.manager_manager_id)
    payload = DiscardCreate(**{**request.model_dump(), "manager_manager_id": manager_id})
    return discard_service.create_discard(db, payload)


@router.get("", response_model=list[DiscardResponse])
def get_discards(
    limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
    db=Depends(get_db),
):
    return discard_service.get_discards(db, limit, offset)


@router.get("/{manager_id}/{sell_product_code}", response_model=DiscardResponse)
def get_discard(
    manager_id: str = Path(min_length=1, max_length=45),
    sell_product_code: str = Path(min_length=1, max_length=80),
    db=Depends(get_db),
):
    discard = discard_service.get_discard(db, manager_id, sell_product_code)
    if discard is None:
        raise HTTPException(status_code=404, detail="폐기 이력을 찾을 수 없습니다.")
    return discard
