from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_manager
from schemas.delivery_company import DeliveryCompanyCreate, DeliveryCompanyResponse
from services import delivery_company_service

# 배송을 등록하는 매니저와 상위 권한 director가 업체를 관리한다.
router = APIRouter(prefix="/delivery_company", tags=["delivery_company"], dependencies=[Depends(get_current_manager)])


@router.post("", response_model=DeliveryCompanyResponse, status_code=201)
def create_delivery_company(request: DeliveryCompanyCreate, db=Depends(get_db)):
    return delivery_company_service.create_delivery_company(db, request)


@router.get("", response_model=list[DeliveryCompanyResponse])
def get_delivery_companies(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db=Depends(get_db),
):
    return delivery_company_service.get_delivery_companies(db, limit, offset)


@router.get("/{delivery_company_code}", response_model=DeliveryCompanyResponse)
def get_delivery_company_code(
    delivery_company_code: str = Path(min_length=1, max_length=45), db=Depends(get_db),
):
    company = delivery_company_service.get_delivery_company_code(db, delivery_company_code)
    if company is None:
        raise HTTPException(status_code=404, detail="배송업체를 찾을 수 없습니다.")
    return company
