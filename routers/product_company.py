from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_manager
from schemas.product_company import ProductCompanyCreate, ProductCompanyResponse
from services import product_company_service

# 매니저와 상위 권한 director가 제조업체를 등록하고 조회한다.
router = APIRouter(prefix="/product_company", tags=["product_company"], dependencies=[Depends(get_current_manager)])


@router.post("", response_model=ProductCompanyResponse, status_code=201)
def create_product_company(request: ProductCompanyCreate, db=Depends(get_db)):
    return product_company_service.create_product_company(db, request)


@router.get("", response_model=list[ProductCompanyResponse])
def get_product_companies(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db=Depends(get_db),
):
    return product_company_service.get_product_companies(db, limit, offset)


@router.get("/{product_company_code}", response_model=ProductCompanyResponse)
def get_product_company_code(
    product_company_code: str = Path(min_length=1, max_length=45), db=Depends(get_db),
):
    company = product_company_service.get_product_company_code(db, product_company_code)
    if company is None:
        raise HTTPException(status_code=404, detail="제조업체를 찾을 수 없습니다.")
    return company
