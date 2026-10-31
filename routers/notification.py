from fastapi import APIRouter,Depends
from database import get_db
from dependencies import get_current_user
from schemas.notification import NotificationResponse
from services.notification_service import get_notifications
router=APIRouter(prefix='/notifications',tags=['notifications'])
@router.get('',response_model=list[NotificationResponse])
def notifications(db=Depends(get_db),user=Depends(get_current_user)):
    return get_notifications(db,user.user_id)
