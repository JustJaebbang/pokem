from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_director
from schemas.card_info import CardInfoCreate, CardInfoResponse
from services import card_info_service


# 카탈로그 기준정보는 전체 상품 코드에 영향을 주므로 Director만 변경한다.
router = APIRouter(
    prefix="/card_info",
    tags=["card_info"],
    dependencies=[Depends(get_current_director)],
)


@router.post("", response_model=CardInfoResponse, status_code=201)
def create_card_info(request: CardInfoCreate, db=Depends(get_db)):
    return card_info_service.create_card_info(db, request)


@router.get("", response_model=list[CardInfoResponse])
def get_card_infos(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db=Depends(get_db),
):
    return card_info_service.get_card_infos(db, limit, offset)


@router.get("/{serial_code}", response_model=CardInfoResponse)
def get_card_info(
    serial_code: str = Path(min_length=1, max_length=50),
    db=Depends(get_db),
):
    result = card_info_service.get_card_info(db, serial_code)
    if result is None:
        raise HTTPException(status_code=404, detail="카드 기준정보를 찾을 수 없습니다.")
    return result
