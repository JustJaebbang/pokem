from fastapi import APIRouter, Depends, Path
from database import get_db
from dependencies import get_current_user
from schemas.push import PushDeviceRequest, PushDeviceResult
from services import push_service

router=APIRouter(prefix='/push/devices',tags=['push'])

@router.put('/{installation_id}',response_model=PushDeviceResult)
def register_device(data: PushDeviceRequest,installation_id: str=Path(pattern=r'^[0-9a-f]{32}$'),db=Depends(get_db),user=Depends(get_current_user)):
    return push_service.register_device(db,installation_id,user.user_id,data.fid)

@router.delete('/{installation_id}',response_model=PushDeviceResult)
def unregister_device(installation_id: str=Path(pattern=r'^[0-9a-f]{32}$'),db=Depends(get_db),user=Depends(get_current_user)):
    return push_service.unregister_device(db,installation_id,user.user_id)
