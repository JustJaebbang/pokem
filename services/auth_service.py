from fastapi import HTTPException

from schemas.auth import LoginRequest, LoginResponse, UserTokenResponse, ManagerTokenResponse
from security import create_access_token
from services import manager_service, user_service


def login(db, request: LoginRequest) -> LoginResponse:
    matches = []
    # 한쪽이 성공해도 다른 테이블을 확인하여 중복 계정을 감지합니다.
    checks = (user_service.login_user, manager_service.login_manager)
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
            detail="사용자와 관리자 계정 정보가 중복됩니다. 계정 ID를 변경해 주세요.",
        )
    account = matches[0]
    subject = account.account.user_id if account.role == "user" else account.account.manager_id
    token, expires_in = create_access_token(subject, account.role)
    response_model = UserTokenResponse if account.role == "user" else ManagerTokenResponse
    return response_model(
        **account.model_dump(),
        access_token=token,
        expires_in=expires_in,
    )
