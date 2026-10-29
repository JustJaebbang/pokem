from fastapi import APIRouter, Depends, HTTPException

from database import get_db
from dependencies import get_current_account, get_current_user, ensure_self, ensure_account_access, resolve_user_id
from schemas.purchase_item import PurchaseItemCreate, PurchaseItemRequest, PurchaseItemResponse, PurchaseItemConfirmResponse
from services import purchase_item_service

router = APIRouter(prefix="/purchase_item", tags=["purchase_item"])


# 구매자는 로그인한 사용자로 확정합니다.
@router.post("", response_model=PurchaseItemResponse, status_code=201)
def create_purchase_item(purchase: PurchaseItemRequest, db=Depends(get_db), current_user=Depends(get_current_user)):
    user_id = ensure_self(current_user, purchase.user_user_id)
    purchase = PurchaseItemCreate(**{**purchase.model_dump(), "user_user_id": user_id})
    return purchase_item_service.create_purchase_item(db, purchase)


@router.get("", response_model=list[PurchaseItemResponse])
def get_purchase_item(user_id: str | None = None, db=Depends(get_db), current=Depends(get_current_account)):
    user_id = resolve_user_id(current, user_id)
    return purchase_item_service.get_purchase_item(db, user_id)


@router.get("/{purchase_item_code}", response_model=PurchaseItemResponse)
def get_purchase_item_code(purchase_item_code: str, db=Depends(get_db), current=Depends(get_current_account)):
    purchase = purchase_item_service.get_purchase_item_code(db, purchase_item_code)
    if purchase is None:
        raise HTTPException(status_code=404, detail="구매 정보를 찾을 수 없습니다.")
    ensure_account_access(current, purchase.user_user_id)
    return purchase


@router.post("/{purchase_item_code}/confirm", response_model=PurchaseItemConfirmResponse)
def confirm_purchase_item(purchase_item_code: str, db=Depends(get_db), current_user=Depends(get_current_user)):
    return purchase_item_service.confirm_purchase_item(db, purchase_item_code, current_user.user_id)
