import unittest
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.auth import LoginRequest
from schemas.user import UserCreate, UserResponse
from security import hash_password, verify_password
from services import user_service, manager_service, auth_service
from schemas.manager import ManagerCreate, ManagerResponse


class PasswordSecurityTests(unittest.TestCase):
    def setUp(self):
        self.account = dict(user_id="test-user", user_nickname="nick", user_name="name",
                            user_phone="010", user_email="test@example.com", user_address="address", user_money=0)

    def test_salted_hash_and_verification(self):
        first = hash_password("test-password")
        second = hash_password("test-password")
        self.assertTrue(first.startswith("$argon2id$"))
        self.assertNotEqual(first, second)
        self.assertTrue(verify_password("test-password", first))
        self.assertFalse(verify_password("wrong", first))
        self.assertFalse(verify_password("test-password", "test-password"))
        self.assertFalse(verify_password("test-password", "$argon2id$invalid"))

    def test_signup_hashes_password_and_forces_zero_balance(self):
        payload = UserCreate(**{**self.account, "user_money": 999999, "user_password": "test-password"})
        self.assertNotIn("user_money", UserCreate.model_fields)
        db = MagicMock()
        with patch.object(user_service, "get_user_id", return_value=UserResponse(**self.account)):
            response = user_service.create_user(db, payload)
        parameters = db.cursor.return_value.__enter__.return_value.execute.call_args.args[1]
        self.assertNotEqual(parameters[1], payload.user_password)
        self.assertTrue(verify_password(payload.user_password, parameters[1]))
        self.assertEqual(parameters[-1], 0)
        self.assertNotIn("user_password", response.model_dump())
        db.commit.assert_called_once()

    def test_login_accepts_hash_and_never_returns_password(self):
        db = MagicMock()
        db.cursor.return_value.__enter__.return_value.fetchone.return_value = {
            **self.account, "user_password": hash_password("test-password")}
        response = user_service.login_user(db, LoginRequest(login_id="test-user", password="test-password"))
        self.assertEqual(response.account.user_id, "test-user")
        self.assertNotIn("user_password", response.account.model_dump())

    def test_login_rejects_missing_wrong_and_plaintext_passwords(self):
        for record in (None, {**self.account, "user_password": hash_password("other")},
                       {**self.account, "user_password": "test-password"}):
            with self.subTest(record_exists=record is not None):
                db = MagicMock()
                db.cursor.return_value.__enter__.return_value.fetchone.return_value = record
                with self.assertRaises(HTTPException) as error:
                    user_service.login_user(db, LoginRequest(login_id="test-user", password="test-password"))
                self.assertEqual(error.exception.status_code, 401)

    def test_duplicate_signup_is_conflict_and_other_integrity_errors_propagate(self):
        payload = UserCreate(**self.account, user_password="test-password")
        for code in (1062, 1452):
            with self.subTest(code=code):
                db = MagicMock()
                db.cursor.return_value.__enter__.return_value.execute.side_effect = IntegrityError(code, "test error")
                expected = HTTPException if code == 1062 else IntegrityError
                with patch.object(user_service, "hash_password", return_value="hashed"):
                    with self.assertRaises(expected) as error:
                        user_service.create_user(db, payload)
                if code == 1062:
                    self.assertEqual(error.exception.status_code, 409)
                db.rollback.assert_called_once()
                db.commit.assert_not_called()

    def test_signup_write_failure_rolls_back(self):
        payload = UserCreate(**self.account, user_password="test-password")
        db = MagicMock()
        db.cursor.return_value.__enter__.return_value.execute.side_effect = RuntimeError("database failure")
        with self.assertRaises(RuntimeError):
            user_service.create_user(db, payload)
        db.rollback.assert_called_once()
        db.commit.assert_not_called()


class ManagerPasswordSecurityTests(unittest.TestCase):
    def setUp(self):
        self.account = dict(manager_id="test-manager", manager_name="name",
                            manager_phone="010", manager_email="test@example.com", manager_dept="test")

    def test_creation_hashes_password(self):
        payload = ManagerCreate(**self.account, manager_password="test-password")
        db = MagicMock()
        with patch.object(manager_service, "get_manager_id", return_value=ManagerResponse(**self.account)):
            response = manager_service.create_manager(db, payload)
        parameters = db.cursor.return_value.__enter__.return_value.execute.call_args.args[1]
        self.assertNotEqual(parameters[1], payload.manager_password)
        self.assertTrue(verify_password(payload.manager_password, parameters[1]))
        self.assertNotIn("manager_password", response.model_dump())
        db.commit.assert_called_once()
        db.rollback.assert_not_called()

    def test_login_through_common_auth_preserves_manager_role(self):
        db = MagicMock()
        db.cursor.return_value.__enter__.return_value.fetchone.side_effect = [
            None, {**self.account, "manager_password": hash_password("test-password")}, None]
        response = auth_service.login(db, LoginRequest(login_id="test-manager", password="test-password"))
        self.assertEqual(response.role, "manager")
        self.assertEqual(response.account.manager_id, "test-manager")
        self.assertNotIn("manager_password", response.account.model_dump())

    def test_login_rejects_wrong_missing_plaintext_and_invalid_hash(self):
        for record in (None, {**self.account, "manager_password": hash_password("other")},
                       {**self.account, "manager_password": "test-password"},
                       {**self.account, "manager_password": "$argon2id$invalid"}):
            with self.subTest(record_exists=record is not None):
                db = MagicMock()
                db.cursor.return_value.__enter__.return_value.fetchone.return_value = record
                with self.assertRaises(HTTPException) as error:
                    manager_service.login_manager(db, LoginRequest(login_id="test-manager", password="test-password"))
                self.assertEqual(error.exception.status_code, 401)

    def test_creation_failure_rolls_back(self):
        payload = ManagerCreate(**self.account, manager_password="test-password")
        db = MagicMock()
        db.cursor.return_value.__enter__.return_value.execute.side_effect = RuntimeError("database failure")
        with self.assertRaises(RuntimeError):
            manager_service.create_manager(db, payload)
        db.rollback.assert_called_once()
        db.commit.assert_not_called()


if __name__ == "__main__":
    unittest.main()
