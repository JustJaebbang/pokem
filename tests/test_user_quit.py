import unittest
from unittest.mock import MagicMock, patch
from types import SimpleNamespace

from fastapi import HTTPException
from pymysql.err import IntegrityError
from pydantic import ValidationError

from routers.user import delete_user_id as delete_endpoint
from schemas.user import UserQuitRequest, UserQuitResponse
from services.user_service import delete_user_id


class UserQuitTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.cursor.fetchone.return_value = {"user_id": "test-user"}
        self.request = UserQuitRequest(quit_reason="test reason")

    def test_success_inserts_before_deleting_and_commits_once(self):
        result = delete_user_id(self.db, self.request, "test-user")
        self.assertIsInstance(result, UserQuitResponse)
        self.assertEqual(result.user_id, "test-user")
        self.assertEqual(result.quit_reason, "test reason")
        self.assertTrue(result.quit_date.endswith("+09:00"))
        calls = self.cursor.execute.call_args_list
        self.assertIn("FOR UPDATE", calls[0].args[0])
        self.assertIn("INSERT INTO `quit`", calls[1].args[0])
        self.assertEqual(calls[1].args[1], ("test-user", result.quit_date, "test reason"))
        self.assertIn("DELETE FROM `user`", " ".join(calls[2].args[0].split()))
        self.assertEqual(calls[2].args[1], ("test-user",))
        self.db.begin.assert_called_once()
        self.db.commit.assert_called_once()
        self.db.rollback.assert_not_called()

    def test_missing_user_does_not_insert_or_delete(self):
        self.cursor.fetchone.return_value = None
        self.assertIsNone(delete_user_id(self.db, self.request, "missing"))
        self.assertEqual(self.cursor.execute.call_count, 1)
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_foreign_key_conflict_rolls_back_insert(self):
        self.cursor.execute.side_effect = [None, None, IntegrityError(1451, "blocked")]
        with self.assertRaises(HTTPException) as error:
            delete_user_id(self.db, self.request, "test-user")
        self.assertEqual(error.exception.status_code, 409)
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_duplicate_record_does_not_delete_user(self):
        self.cursor.execute.side_effect = [None, IntegrityError(1062, "duplicate")]
        with self.assertRaises(HTTPException) as error:
            delete_user_id(self.db, self.request, "test-user")
        self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(self.cursor.execute.call_count, 2)
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_database_failure_rolls_back(self):
        self.cursor.execute.side_effect = RuntimeError("failure")
        with self.assertRaises(RuntimeError):
            delete_user_id(self.db, self.request, "test-user")
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_missing_user_returns_404(self):
        with patch("routers.user.user_service.delete_user_id", return_value=None):
            with self.assertRaises(HTTPException) as error:
                delete_endpoint("missing", self.request, self.db, current_user=SimpleNamespace(user_id="missing"))
        self.assertEqual(error.exception.status_code, 404)

    def test_reason_is_optional_and_length_is_limited(self):
        self.assertIsNone(UserQuitRequest().quit_reason)
        with self.assertRaises(ValidationError):
            UserQuitRequest(quit_reason="x" * 201)


if __name__ == "__main__":
    unittest.main()
