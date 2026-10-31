from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_account, get_current_manager, ensure_manager_self
from schemas.delivery import DeliveryCreate, DeliveryRequest, DeliveryResponse, DeliveryStatusUpdate
from services import delivery_service

router = APIRouter(prefix="/delivery", tags=["delivery"])


@router.post("", response_model=DeliveryResponse, status_code=201)
def create_delivery(request: DeliveryRequest, db=Depends(get_db), manager=Depends(get_current_manager)):
    # 매니저만 등록 가능하며, 다른 매니저 ID를 지정하는 요청은 거부한다.
    manager_id = ensure_manager_self(manager, request.manager_manager_id)
    payload = DeliveryCreate(**{**request.model_dump(), "manager_manager_id": manager_id})
    return delivery_service.create_delivery(db, payload)


@router.get("", response_model=list[DeliveryResponse])
def get_deliveries(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db=Depends(get_db),
    current=Depends(get_current_account),
):
    # 일반 사용자는 본인 배송만, 매니저는 전체 배송을 조회한다.
    user_id = current.account.user_id if current.role == "user" else None
    return delivery_service.get_deliveries(db, limit, offset, user_id=user_id)


@router.patch("/{delivery_no}/status", response_model=DeliveryResponse)
def update_delivery_status(
    request: DeliveryStatusUpdate,
    delivery_no: str = Path(min_length=1, max_length=64),
    db=Depends(get_db),
    manager=Depends(get_current_manager),
):
    # 로그인한 매니저 또는 상위 권한만 정해진 순서로 배송 상태를 변경한다.
    return delivery_service.update_delivery_status(db, delivery_no, request.delivery_status)


@router.get("/{delivery_no}", response_model=DeliveryResponse)
def get_delivery(
    delivery_no: str = Path(min_length=1, max_length=64),
    db=Depends(get_db),
    current=Depends(get_current_account),
):
    # 본인 배송이 아니면 존재하지 않는 번호와 동일하게 404를 반환한다.
    user_id = current.account.user_id if current.role == "user" else None
    delivery = delivery_service.get_delivery(db, delivery_no, user_id=user_id)
    if delivery is None:
        raise HTTPException(status_code=404, detail="배송 내역을 찾을 수 없습니다.")
    return delivery
