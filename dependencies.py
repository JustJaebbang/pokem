from services.sale_registration_service import get_sale_registrations
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from database import get_db
from schemas.user import UserResponse, UserLoginResponse
from schemas.manager import ManagerResponse, ManagerLoginResponse
from schemas.director import DirectorResponse, DirectorLoginResponse
from security import decode_access_token
from services import user_service, manager_service, director_service


bearer = HTTPBearer(auto_error=False)


def get_current_account(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db=Depends(get_db),
) -> UserLoginResponse | ManagerLoginResponse | DirectorLoginResponse:
    if credentials is None:
        raise HTTPException(status_code=401, detail="로그인이 필요합니다.", headers={"WWW-Authenticate": "Bearer"})
    claims = decode_access_token(credentials.credentials)
    if claims["role"] == "user":
        account = user_service.get_user_id(db, claims["sub"])
        if account is not None:
            return UserLoginResponse(account=account)
    elif claims["role"] == "manager":
        account = manager_service.get_manager_id(db, claims["sub"])
        if account is not None:
            return ManagerLoginResponse(account=account)
    elif claims["role"] == "director":
        account = director_service.get_director_id(db, claims["sub"])
        if account is not None:
            return DirectorLoginResponse(account=account)
    # 유효한 토큰이라도 삭제되었거나 quit 기록이 있는 사용자 계정은 인증하지 않습니다.
    raise HTTPException(status_code=401, detail="유효한 계정을 찾을 수 없습니다.", headers={"WWW-Authenticate": "Bearer"})


def get_current_user(current=Depends(get_current_account)) -> UserResponse:
    if current.role != "user":
        raise HTTPException(status_code=403, detail="일반 사용자 계정이 필요합니다.")
    return current.account


def get_current_manager(current=Depends(get_current_account)) -> ManagerResponse | DirectorResponse:
    # director는 매니저 기능에 접근할 수 있는 상위 권한이다.
    if current.role not in ("manager", "director"):
        raise HTTPException(status_code=403, detail="관리자 권한이 필요합니다.")
    return current.account


def get_current_manager_only(current=Depends(get_current_account)) -> ManagerResponse:
    # 주문·입고처럼 실제 매니저만 수행하는 업무에 사용한다.
    if current.role != "manager":
        raise HTTPException(status_code=403, detail="매니저 계정만 사용할 수 있습니다.")
    return current.account


def get_current_director(current=Depends(get_current_account)) -> DirectorResponse:
    if current.role != "director":
        raise HTTPException(status_code=403, detail="director 권한이 필요합니다.")
    return current.account


def ensure_self(user: UserResponse, requested_id: str | None = None) -> str:
    if requested_id is not None and requested_id != user.user_id:
        raise HTTPException(status_code=403, detail="본인 계정만 처리할 수 있습니다.")
    return user.user_id



def ensure_manager_self(manager: ManagerResponse, requested_id: str | None = None) -> str:
    if requested_id is not None and requested_id != manager.manager_id:
        raise HTTPException(status_code=403, detail="본인 계정만 처리할 수 있습니다.")
    return manager.manager_id


def ensure_account_access(current, user_id: str) -> None:
    if current.role not in ("manager", "director"):
        ensure_self(current.account, user_id)


def ensure_manager_self(manager: ManagerResponse | DirectorResponse, requested_id: str | None = None) -> str:
    # 매니저 외래키가 필요한 작업에서는 director가 실제 담당 매니저를 지정한다.
    # director ID를 manager 테이블의 ID로 저장하지 않는다.
    if isinstance(manager, DirectorResponse):
        if not requested_id:
            raise HTTPException(status_code=422, detail="담당 매니저의 manager_manager_id를 지정해주세요.")
        return requested_id
    if requested_id is not None and requested_id != manager.manager_id:
        raise HTTPException(status_code=403, detail="로그인한 매니저 ID만 사용할 수 있습니다.")
    return manager.manager_id


def resolve_user_id(current, requested_id: str | None) -> str:
    if current.role == "user":
        return ensure_self(current.account, requested_id)
    if not requested_id:
        raise HTTPException(status_code=422, detail="조회할 user_id를 지정해주세요.")
    return requested_id


def require_sell_product_owner(db, sell_product_code: str, user_id: str, role: str = "user", action: str = "edit") -> None:
    # 검사와 서비스의 수정·삭제가 같은 연결/트랜잭션에서 수행되도록 잠급니다.
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT sell_product_code
            FROM sell_product
            WHERE sell_product_code = %s
            FOR UPDATE
            """,
            (sell_product_code,),
        )
        if cursor.fetchone() is None:
            raise HTTPException(status_code=404, detail="판매상품을 찾을 수 없습니다.")
        owners = get_sale_registrations(cursor, sell_product_code)
        allowed = len(owners) == 1 and (
            role == "manager" if owners[0].get("registration_type", "direct") == "consign"
            else role == "user" and owners[0]["user_user_id"] == user_id
        )
        if not allowed:
            raise HTTPException(status_code=403, detail="본인이 등록한 상품만 변경할 수 있습니다.")
        if owners[0].get("registration_type", "direct") == "consign" and action == "delete":
            raise HTTPException(status_code=409, detail="대리판매 상품의 삭제는 별도 회수 절차가 필요합니다.")
