from fastapi import APIRouter, Depends

from database import get_db
from dependencies import get_current_user, ensure_self
from schemas.wishlist import WishlistRequest, WishlistResponse
from services import wishlist_service

router = APIRouter(prefix="/wishlist", tags=["wishlist"])

# 로그인한 사용자의 관심상품만 처리합니다.
@router.post("", response_model=WishlistResponse)
def create_wishlist(wishlist: WishlistRequest, db=Depends(get_db), current_user=Depends(get_current_user)):
    user_id = ensure_self(current_user, wishlist.user_user_id)
    return wishlist_service.set_wishlist(
        db, user_id, wishlist.sell_product_sell_product_code, True
    )


@router.get("/{user_id}", response_model=list[WishlistResponse])
def get_wishlist(user_id: str, db=Depends(get_db), current_user=Depends(get_current_user)):
    user_id = ensure_self(current_user, user_id)
    return wishlist_service.get_wishlist(db, user_id)


@router.delete("/{user_id}/{sell_product_code}", response_model=WishlistResponse)
def delete_wishlist(user_id: str, sell_product_code: str, db=Depends(get_db), current_user=Depends(get_current_user)):
    user_id = ensure_self(current_user, user_id)
    return wishlist_service.set_wishlist(db, user_id, sell_product_code, False)
