from fastapi import APIRouter, Depends, HTTPException, Query
from typing import Literal

from database import get_db
from dependencies import get_current_user, get_current_account, require_sell_product_owner

from schemas.sell_product import SellProductCreate, SellProductResponse, SellProductUpdate, SellProductDelete
from services import sell_product_service

router = APIRouter(prefix="/sell_product", tags=["sell_product"])

# 로그인한 사용자를 판매자로 저장합니다.
@router.post("", response_model=SellProductResponse, status_code=201)
def create_sell_product(sp: SellProductCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    return sell_product_service.create_sell_product(db, sp, current_user.user_id)


# 모든 sell_product 가져오기
@router.get("", response_model=list[SellProductResponse])
def get_sell_product(
    q: str | None = Query(default=None, max_length=200),
    status: Literal['판매중','거래중','거래완료'] | None = None,
    sort: Literal['newest','price_asc','price_desc'] | None = None,
    limit: int | None = Query(default=None, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    codes: list[str] | None = Query(default=None, max_length=100),
    category: str | None = Query(default=None, min_length=1, max_length=30),
    brand: str | None = Query(default=None, min_length=1, max_length=50),
    db=Depends(get_db),
):
    if codes is not None and any(not code or len(code)>80 for code in codes):
        raise HTTPException(status_code=422, detail='상품 코드를 확인해주세요.')
    if offset and limit is None:
        raise HTTPException(status_code=422, detail='offset을 사용할 때 limit을 지정해주세요.')
    sell_products = sell_product_service.get_sell_product(db, q=q, status=status, sort=sort, limit=limit, offset=offset, codes=codes, category=category, brand=brand)
    if sell_products is None:
        raise HTTPException(status_code=404, detail="판매 상품을 찾을 수 없습니다.")
    return sell_products


@router.get("/filters", response_model=list[dict[str, str | None]])
def get_product_filters(db=Depends(get_db)):
    return sell_product_service.get_product_filters(db)


# sell_product_code로 해당 sell_product 가져오기
@router.get("/{sell_product_code}", response_model=SellProductResponse)
def get_sell_product_code(sell_product_code: str, db=Depends(get_db)):
    sell_product = sell_product_service.get_sell_product_code(db, sell_product_code)
    if sell_product is None:
        raise HTTPException(status_code=404, detail="해당 상품을 찾을 수 없습니다.")
    return sell_product


# sell_product_code로 해당 sell_product 정보 변경
@router.put("/{sell_product_code}", response_model=SellProductResponse)
def put_sell_product_code(sp: SellProductUpdate, sell_product_code: str, db=Depends(get_db), current=Depends(get_current_account)):
    require_sell_product_owner(db, sell_product_code, current.account.user_id if current.role == "user" else current.account.manager_id, current.role)
    sell_product = sell_product_service.put_sell_product_code(db, sp, sell_product_code)
    if sell_product is None:
        raise HTTPException(status_code=404, detail="해당 상품을 찾을 수 없습니다.")
    return sell_product


# sell_product_code로 해당 sell_product 가져오기
@router.delete("/{sell_product_code}", response_model=SellProductDelete)
def delete_sell_product_code(sell_product_code: str, db=Depends(get_db), current=Depends(get_current_account)):
    require_sell_product_owner(db, sell_product_code, current.account.user_id if current.role == "user" else current.account.manager_id, current.role, action="delete")
    deleted_sell_product = sell_product_service.delete_sell_product_code(db, sell_product_code)
    if deleted_sell_product is None:
        raise HTTPException(status_code=404, detail="해당 상품을 찾을 수 없습니다.")
    return deleted_sell_product

@router.post("/{sell_product_code}/relist", response_model=SellProductResponse)
def relist_sell_product(sell_product_code: str, db=Depends(get_db), current=Depends(get_current_account)):
    return sell_product_service.relist_sell_product(db, sell_product_code, current.account.user_id if current.role == "user" else current.account.manager_id, current.role)
