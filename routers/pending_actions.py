from fastapi import APIRouter, Depends
from database import get_db
from dependencies import get_current_user
from schemas.pending_actions import PendingActionsResponse
from services.pending_actions_service import get_pending_actions
router = APIRouter(prefix='/mypage', tags=['mypage'])
@router.get('/pending-actions', response_model=PendingActionsResponse)
def pending_actions(db=Depends(get_db), user=Depends(get_current_user)):
    return get_pending_actions(db, user.user_id)
