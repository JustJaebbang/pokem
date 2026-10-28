import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

import jwt
from dotenv import load_dotenv
from fastapi import HTTPException

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError


load_dotenv(Path(__file__).resolve().parent / ".env")

_password_hasher = PasswordHasher()
_JWT_ALGORITHM = "HS256"
_JWT_ISSUER = "pokem-api"
_JWT_AUDIENCE = "pokem-app"


def hash_password(password: str) -> str:
    return _password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _password_hasher.verify(password_hash, password)
    except (InvalidHashError, VerificationError):
        return False


def _jwt_secret() -> str:
    secret = os.environ.get("JWT_SECRET_KEY", "")
    if len(secret.encode("utf-8")) < 32:
        raise RuntimeError("JWT_SECRET_KEY에 최소 32바이트의 무작위 비밀키를 설정해주세요.")
    return secret


def create_access_token(subject: str, role: str) -> tuple[str, int]:
    if not subject or role not in ("user", "manager"):
        raise ValueError("토큰의 계정 ID 또는 역할이 올바르지 않습니다.")
    minutes = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES", "30"))
    if minutes <= 0:
        raise ValueError("ACCESS_TOKEN_EXPIRE_MINUTES는 양수여야 합니다.")
    expires_in = minutes * 60
    now = datetime.now(timezone.utc)
    claims = {
        "sub": subject,
        "role": role,
        "token_type": "access",
        "iat": now,
        "exp": now + timedelta(seconds=expires_in),
        "iss": _JWT_ISSUER,
        "aud": _JWT_AUDIENCE,
        "jti": uuid4().hex,
    }
    return jwt.encode(claims, _jwt_secret(), algorithm=_JWT_ALGORITHM), expires_in


def decode_access_token(token: str) -> dict:
    secret = _jwt_secret()
    try:
        claims = jwt.decode(
            token,
            secret,
            algorithms=[_JWT_ALGORITHM],
            issuer=_JWT_ISSUER,
            audience=_JWT_AUDIENCE,
            options={"require": ["sub", "role", "token_type", "iat", "exp", "iss", "aud", "jti"]},
        )
        if (
            not isinstance(claims["sub"], str) or not claims["sub"]
            or claims["role"] not in ("user", "manager")
            or claims["token_type"] != "access"
            or not isinstance(claims["jti"], str) or not claims["jti"]
            or type(claims["iat"]) is not int
            or type(claims["exp"]) is not int
            or claims["exp"] <= claims["iat"]
        ):
            raise jwt.InvalidTokenError("Invalid access token claims")
        return claims
    except jwt.InvalidTokenError as exc:
        raise HTTPException(
            status_code=401,
            detail="유효하지 않거나 만료된 인증 토큰입니다.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc
