from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_director
from schemas.director import DirectorCreate, DirectorResponse
from services import director_service

# 하위 권한인 매니저가 상위 계정을 생성하거나 조회할 수 없도록 제한한다.
router = APIRouter(prefix="/director", tags=["director"], dependencies=[Depends(get_current_director)])


@router.post("", response_model=DirectorResponse, status_code=201)
def create_director(request: DirectorCreate, db=Depends(get_db)):
    return director_service.create_director(db, request)


@router.get("", response_model=list[DirectorResponse])
def get_directors(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db=Depends(get_db),
):
    return director_service.get_directors(db, limit, offset)


@router.get("/{director_id}", response_model=DirectorResponse)
def get_director_id(director_id: str = Path(min_length=1, max_length=45), db=Depends(get_db)):
    director = director_service.get_director_id(db, director_id)
    if director is None:
        raise HTTPException(status_code=404, detail="director를 찾을 수 없습니다.")
    return director
