from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_manager_only, ensure_manager_self
from schemas.order import OrderCreate, OrderRequest, OrderResponse
from services import order_service


router = APIRouter(prefix="/order", tags=["order"], dependencies=[Depends(get_current_manager_only)])


@router.post("", response_model=OrderResponse, status_code=201)
def create_order(request: OrderRequest, db=Depends(get_db), manager=Depends(get_current_manager_only)):
    manager_id = ensure_manager_self(manager, request.manager_manager_id)
    payload = OrderCreate(**{**request.model_dump(), "manager_manager_id": manager_id})
    return order_service.create_order(db, payload)


@router.get("", response_model=list[OrderResponse])
def get_orders(
    limit: int = Query(default=20, ge=1, le=100), offset: int = Query(default=0, ge=0),
    db=Depends(get_db), manager=Depends(get_current_manager_only),
):
    return order_service.get_orders(db, limit, offset, manager_id=manager.manager_id)


@router.get("/{order_no}", response_model=OrderResponse)
def get_order(
    order_no: str = Path(min_length=1, max_length=64),
    db=Depends(get_db), manager=Depends(get_current_manager_only),
):
    order = order_service.get_order(db, order_no, manager_id=manager.manager_id)
    if order is None:
        raise HTTPException(status_code=404, detail="주문을 찾을 수 없습니다.")
    return order
