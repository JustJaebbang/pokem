from fastapi import APIRouter, Depends, HTTPException

from database import get_db
from dependencies import get_current_user
from schemas.review import ReviewCreate, ReviewResponse
from services import review_service

router = APIRouter(prefix="/review", tags=["review"])


@router.post("", response_model=ReviewResponse, status_code=201)
def create_review(review: ReviewCreate, db=Depends(get_db), current_user=Depends(get_current_user)):
    return review_service.create_review(db, review, current_user.user_id)


@router.get("", response_model=list[ReviewResponse])
def get_review(sell_product_code: str | None = None, db=Depends(get_db)):
    return review_service.get_review(db, sell_product_code)


@router.get("/{review_code}", response_model=ReviewResponse)
def get_review_code(review_code: str, db=Depends(get_db)):
    review = review_service.get_review_code(db, review_code)
    if review is None:
        raise HTTPException(status_code=404, detail="리뷰를 찾을 수 없습니다.")
    return review
