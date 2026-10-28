import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import jwt
from fastapi import HTTPException
from fastapi.testclient import TestClient

from database import get_db
from main import app
from schemas.auth import LoginRequest
from schemas.user import UserLoginResponse, UserResponse
from schemas.manager import ManagerLoginResponse, ManagerResponse
from security import create_access_token, decode_access_token
from services import auth_service


class AccessTokenTests(unittest.TestCase):
    def setUp(self):
        self.settings = patch.dict(os.environ, {"JWT_SECRET_KEY": "test-signing-key-" * 4, "ACCESS_TOKEN_EXPIRE_MINUTES": "30"})
        self.settings.start()
        self.addCleanup(self.settings.stop)
        self.user = UserLoginResponse(account=UserResponse(
            user_id="test-user", user_nickname="nick", user_name="name", user_phone="010",
            user_email="test@example.com", user_address="address", user_money=0))
        self.manager = ManagerLoginResponse(account=ManagerResponse(
            manager_id="test-manager", manager_name="name", manager_phone="010",
            manager_email="test@example.com", manager_dept="test"))

    def unsigned_claims(self):
        token, _ = create_access_token("test-user", "user")
        return decode_access_token(token)

    def encode(self, claims, **kwargs):
        return jwt.encode(claims, kwargs.get("key", os.environ["JWT_SECRET_KEY"]), algorithm=kwargs.get("algorithm", "HS256"))

    def assert_unauthorized(self, token):
        with self.assertRaises(HTTPException) as error:
            decode_access_token(token)
        self.assertEqual(error.exception.status_code, 401)
        self.assertEqual(error.exception.headers["WWW-Authenticate"], "Bearer")

    def test_both_roles_and_expiry(self):
        for role in ("user", "manager"):
            token, seconds = create_access_token("same-id", role)
            claims = decode_access_token(token)
            self.assertEqual(claims["sub"], "same-id")
            self.assertEqual(claims["role"], role)
            self.assertEqual(claims["token_type"], "access")
            self.assertEqual(seconds, 1800)
            self.assertEqual(claims["exp"] - claims["iat"], seconds)
            self.assertNotIn("password", claims)
            self.assertNotIn("user_money", claims)

    def test_expired_and_wrong_signatures_rejected(self):
        claims = self.unsigned_claims()
        past = datetime.now(timezone.utc) - timedelta(hours=1)
        claims.update(iat=int(past.timestamp()), exp=int((past + timedelta(minutes=30)).timestamp()))
        self.assert_unauthorized(self.encode(claims))
        claims = self.unsigned_claims()
        self.assert_unauthorized(self.encode(claims, key="another-key-" * 5))
        self.assert_unauthorized(self.encode(claims, algorithm="HS384"))
        self.assert_unauthorized("not-a-token")

    def test_missing_required_claims_rejected(self):
        for name in ("sub", "role", "token_type", "iat", "exp", "iss", "aud", "jti"):
            with self.subTest(name=name):
                claims = self.unsigned_claims()
                del claims[name]
                self.assert_unauthorized(self.encode(claims))

    def test_invalid_claims_rejected(self):
        for name, value in (("role", "admin"), ("sub", ""), ("token_type", "refresh"),
                            ("iss", "other-api"), ("aud", "other-app"), ("exp", "invalid"), ("jti", "")):
            with self.subTest(name=name):
                claims = self.unsigned_claims()
                claims[name] = value
                self.assert_unauthorized(self.encode(claims))

    def test_expiry_configuration_and_missing_key(self):
        with patch.dict(os.environ, {"ACCESS_TOKEN_EXPIRE_MINUTES": "5"}):
            _, seconds = create_access_token("test-user", "user")
            self.assertEqual(seconds, 300)
        with patch.dict(os.environ, {"JWT_SECRET_KEY": ""}):
            with self.assertRaises(RuntimeError):
                create_access_token("test-user", "user")
        with patch.dict(os.environ, {"ACCESS_TOKEN_EXPIRE_MINUTES": "0"}):
            with self.assertRaises(ValueError):
                create_access_token("test-user", "user")

    def test_login_issues_correct_role_token(self):
        invalid = HTTPException(status_code=401)
        for account in (self.user, self.manager):
            with self.subTest(role=account.role):
                with patch.object(auth_service.user_service, "login_user", **({"return_value": account} if account.role == "user" else {"side_effect": invalid})), patch.object(auth_service.manager_service, "login_manager", **({"return_value": account} if account.role == "manager" else {"side_effect": invalid})):
                    result = auth_service.login(MagicMock(), LoginRequest(login_id="test", password="test-password"))
                claims = decode_access_token(result.access_token)
                self.assertEqual(claims["role"], account.role)
                expected_id = account.account.user_id if account.role == "user" else account.account.manager_id
                self.assertEqual(claims["sub"], expected_id)
                self.assertEqual(result.account, account.account)

    def test_failed_or_ambiguous_login_never_issues_token(self):
        for user, manager, status in ((None, None, 401), (self.user, self.manager, 409)):
            with self.subTest(status=status):
                with patch.object(auth_service.user_service, "login_user", **({"return_value": user} if user else {"side_effect": HTTPException(status_code=401)})), patch.object(auth_service.manager_service, "login_manager", **({"return_value": manager} if manager else {"side_effect": HTTPException(status_code=401)})), patch.object(auth_service, "create_access_token") as issue:
                    with self.assertRaises(HTTPException) as error:
                        auth_service.login(MagicMock(), LoginRequest(login_id="test", password="test-password"))
                    self.assertEqual(error.exception.status_code, status)
                    issue.assert_not_called()

    def test_http_login_response_and_cache_headers(self):
        app.dependency_overrides[get_db] = lambda: MagicMock()
        try:
            with TestClient(app) as client:
                for account in (self.user, self.manager):
                    with self.subTest(role=account.role):
                        with patch.object(auth_service.user_service, "login_user", **({"return_value": account} if account.role == "user" else {"side_effect": HTTPException(status_code=401)})), patch.object(auth_service.manager_service, "login_manager", **({"return_value": account} if account.role == "manager" else {"side_effect": HTTPException(status_code=401)})):
                            response = client.post("/auth/login", json={"login_id": "test", "password": "test-password"})
                        self.assertEqual(response.status_code, 200)
                        body = response.json()
                        self.assertEqual(body["token_type"], "bearer")
                        self.assertEqual(body["expires_in"], 1800)
                        self.assertEqual(decode_access_token(body["access_token"])["role"], account.role)
                        self.assertEqual(response.headers["Cache-Control"], "no-store")
        finally:
            app.dependency_overrides.clear()


if __name__ == "__main__":
    unittest.main()
