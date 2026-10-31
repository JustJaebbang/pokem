from fastapi import APIRouter, Depends, Request, Response
from database import get_db
from schemas.account_recovery import RecoveryRequest, RecoveryComplete, RecoveryChallenge, RecoveryResult
from services import account_recovery_service

router = APIRouter(prefix="/auth/recovery", tags=["auth"])

@router.post("/request", response_model=RecoveryChallenge)
def request_code(data: RecoveryRequest, request: Request, response: Response, db=Depends(get_db)):
    response.headers['Cache-Control'] = 'no-store'
    return account_recovery_service.request_code(db, data, request.client.host if request.client else 'unknown')

@router.post("/complete", response_model=RecoveryResult)
def complete(data: RecoveryComplete, response: Response, db=Depends(get_db)):
    response.headers['Cache-Control'] = 'no-store'
    return account_recovery_service.complete(db, data)
