from fastapi import APIRouter, Depends, HTTPException

from database import get_db

from schemas.post_item import PostItemResponse 
from services import post_item_service

router = APIRouter(prefix="/post_item", tags=["post_item"])

# 모든 post_item 가져오기
@router.get("", response_model=list[PostItemResponse])
def get_post_items(db=Depends(get_db)):
    post_items = post_item_service.get_post_item(db)
    if post_items is None:
        raise HTTPException(status_code=404, detail="상품등록 정보를 찾을 수 없습니다.")
    return post_items

# post_item_code로 해당 post_item 가져오기
@router.get("/{post_item_code}", response_model=PostItemResponse)
def get_post_items_code(post_item_code: str, db=Depends(get_db)):
    post_item = post_item_service.get_post_item_code(db, post_item_code)
    if post_item is None:
        raise HTTPException(status_code=404, detail="해당 상품등록 정보를 찾을 수 없습니다.")
    return post_item
