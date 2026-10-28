from fastapi import APIRouter, Depends, HTTPException

from database import get_db
from schemas.purchase_item import PurchaseItemCreate, PurchaseItemResponse
from services import purchase_item_service

router = APIRouter(prefix="/purchase_item", tags=["purchase_item"])


# 로그인 기능 연결 시 구매자와 조회 사용자를 현재 로그인한 사용자로 제한합니다.
@router.post("", response_model=PurchaseItemResponse, status_code=201)
def create_purchase_item(purchase: PurchaseItemCreate, db=Depends(get_db)):
    return purchase_item_service.create_purchase_item(db, purchase)


@router.get("", response_model=list[PurchaseItemResponse])
def get_purchase_item(user_id: str, db=Depends(get_db)):
    return purchase_item_service.get_purchase_item(db, user_id)


@router.get("/{purchase_item_code}", response_model=PurchaseItemResponse)
def get_purchase_item_code(purchase_item_code: str, db=Depends(get_db)):
    purchase = purchase_item_service.get_purchase_item_code(db, purchase_item_code)
    if purchase is None:
        raise HTTPException(status_code=404, detail="구매 정보를 찾을 수 없습니다.")
    return purchase
