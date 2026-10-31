from fastapi import APIRouter, Depends
from database import get_db
from dependencies import get_current_user
from schemas.sale_history import SaleHistoryResponse
from services.sale_history_service import get_sale_history

router = APIRouter(prefix='/sale_history', tags=['sale_history'])

@router.get('', response_model=list[SaleHistoryResponse])
def list_my_sales(db=Depends(get_db), current_user=Depends(get_current_user)):
    return get_sale_history(db, current_user.user_id)
