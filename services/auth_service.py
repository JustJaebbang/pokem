from fastapi import HTTPException

from schemas.auth import LoginRequest, LoginResponse, UserTokenResponse, ManagerTokenResponse, DirectorTokenResponse
from security import create_access_token
from services import manager_service, user_service, director_service


def login(db, request: LoginRequest) -> LoginResponse:
    matches = []
    # 모든 계정 테이블을 확인해 역할 간 중복 인증을 감지한다.
    checks = (user_service.login_user, manager_service.login_manager, director_service.login_director)
    for authenticate in checks:
        try:
            matches.append(authenticate(db, request))
        except HTTPException as exc:
            # 계정 불일치만 건너뛰고 다른 오류는 그대로 전달합니다.
            if exc.status_code != 401:
                raise

    if not matches:
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다.")
    if len(matches) > 1:
        raise HTTPException(
            status_code=409,
            detail="여러 역할의 계정 정보가 중복됩니다. 계정 ID를 변경해 주세요.",
        )
    account = matches[0]
    id_field = {"user": "user_id", "manager": "manager_id", "director": "director_id"}[account.role]
    subject = getattr(account.account, id_field)
    token, expires_in = create_access_token(subject, account.role)
    response_model = {"user": UserTokenResponse, "manager": ManagerTokenResponse, "director": DirectorTokenResponse}[account.role]
    return response_model(
        **account.model_dump(),
        access_token=token,
        expires_in=expires_in,
    )
