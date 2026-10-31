from fastapi import APIRouter,Depends,HTTPException,Path
from database import get_db
from schemas.public_profile import PublicProfileResponse
from services.public_profile_service import get_public_profile
router=APIRouter(prefix='/profiles',tags=['public_profile'])
@router.get('/{user_id}',response_model=PublicProfileResponse)
def public_profile(user_id:str=Path(min_length=1,max_length=20),db=Depends(get_db)):
    result=get_public_profile(db,user_id)
    if result is None: raise HTTPException(status_code=404,detail='사용자 프로필을 찾을 수 없습니다.')
    return result
