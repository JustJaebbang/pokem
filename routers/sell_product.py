from fastapi import APIRouter, Depends, HTTPException

from database import get_db

from schemas.sell_product import SellProductCreate, SellProductResponse, SellProductUpdate, SellProductDelete
from services import sell_product_service

router = APIRouter(prefix="/sell_product", tags=["sell_product"])

# sell_product 생성 create_sell_product에서 파라미터 지금은 로그인 기능이 구현안되서 일단 jaebbang으로 잡음
# 나중에 로그인 기능 구현하면 user_id = current_user["user_id"] 로 수정해야함
@router.post("", response_model=SellProductResponse, status_code=201)
def create_sell_product(sp: SellProductCreate, db=Depends(get_db), user_id='jaebbang'): 
    return sell_product_service.create_sell_product(db, sp, user_id)


# 모든 sell_product 가져오기
@router.get("", response_model=list[SellProductResponse])
def get_sell_product(db=Depends(get_db)):
    sell_products = sell_product_service.get_sell_product(db)
    if sell_products is None:
        raise HTTPException(status_code=404, detail="판매 상품을 찾을 수 없습니다.")
    return sell_products


# sell_product_code로 해당 sell_product 가져오기
@router.get("/{sell_product_code}", response_model=SellProductResponse)
def get_sell_product_code(sell_product_code: str, db=Depends(get_db)):
    sell_product = sell_product_service.get_sell_product_code(db, sell_product_code)
    if sell_product is None:
        raise HTTPException(status_code=404, detail="해당 상품을 찾을 수 없습니다.")
    return sell_product


# sell_product_code로 해당 sell_product 정보 변경
@router.put("/{sell_product_code}", response_model=SellProductResponse)
def put_sell_product_code(sp: SellProductUpdate, sell_product_code: str, db=Depends(get_db)):
    sell_product = sell_product_service.put_sell_product_code(db, sp, sell_product_code)
    if sell_product is None:
        raise HTTPException(status_code=404, detail="해당 상품을 찾을 수 없습니다.")
    return sell_product


# sell_product_code로 해당 sell_product 가져오기
@router.delete("/{sell_product_code}", response_model=SellProductDelete)
def delete_sell_product_code(sell_product_code: str, db=Depends(get_db)):
    deleted_sell_product = sell_product_service.delete_sell_product_code(db, sell_product_code)
    if deleted_sell_product is None:
        raise HTTPException(status_code=404, detail="해당 상품을 찾을 수 없습니다.")
    return deleted_sell_product