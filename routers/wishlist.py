from fastapi import APIRouter, Depends

from database import get_db
from schemas.wishlist import WishlistCreate, WishlistResponse
from services import wishlist_service

router = APIRouter(prefix="/wishlist", tags=["wishlist"])

# 로그인 기능 연결 시 사용자 ID를 현재 로그인한 사용자로 제한해야 합니다.
@router.post("", response_model=WishlistResponse)
def create_wishlist(wishlist: WishlistCreate, db=Depends(get_db)):
    return wishlist_service.set_wishlist(
        db, wishlist.user_user_id, wishlist.sell_product_sell_product_code, True
    )


@router.get("/{user_id}", response_model=list[WishlistResponse])
def get_wishlist(user_id: str, db=Depends(get_db)):
    return wishlist_service.get_wishlist(db, user_id)


@router.delete("/{user_id}/{sell_product_code}", response_model=WishlistResponse)
def delete_wishlist(user_id: str, sell_product_code: str, db=Depends(get_db)):
    return wishlist_service.set_wishlist(db, user_id, sell_product_code, False)
