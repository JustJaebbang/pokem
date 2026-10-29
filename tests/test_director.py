import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock

from fastapi import FastAPI
from fastapi.testclient import TestClient
from pymysql.err import IntegrityError

from database import get_db
from dependencies import get_current_account
from routers.director import router
from schemas.director import DirectorResponse
from security import verify_password


class DirectorTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.current = SimpleNamespace(role="director", account=DirectorResponse(director_id="d"))
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_db] = lambda: self.db
        app.dependency_overrides[get_current_account] = lambda: self.current
        self.client = TestClient(app)
        self.body = {"director_id": "director1", "director_password": "sample-password"}

    def test_create_hashes_password_and_supports_nullable_columns(self):
        response = self.client.post("/director", json=self.body)
        self.assertEqual(response.status_code, 201)
        self.assertNotIn("director_password", response.json())
        self.assertIsNone(response.json()["director_name"])
        stored_hash = self.cursor.execute.call_args.args[1][1]
        self.assertNotEqual(stored_hash, self.body["director_password"])
        self.assertTrue(verify_password(self.body["director_password"], stored_hash))
        self.db.commit.assert_called_once()

    def test_duplicate_id_rolls_back(self):
        self.cursor.execute.side_effect = IntegrityError(1062, "duplicate")
        self.assertEqual(self.client.post("/director", json=self.body).status_code, 409)
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_read_and_missing_director(self):
        self.cursor.fetchone.return_value = {"director_id": "director1"}
        self.assertEqual(self.client.get("/director/director1").status_code, 200)
        self.assertNotIn("director_password", self.cursor.execute.call_args.args[0])
        self.cursor.fetchone.return_value = None
        self.assertEqual(self.client.get("/director/missing").status_code, 404)
        self.cursor.fetchall.return_value = [{"director_id": "director1"}]
        self.assertEqual(len(self.client.get("/director").json()), 1)

    def test_user_cannot_manage_directors(self):
        for role in ("user", "manager"):
            self.current = SimpleNamespace(role=role, account=SimpleNamespace())
            for response in (self.client.post("/director", json=self.body), self.client.get("/director"), self.client.get("/director/director1")):
                self.assertEqual(response.status_code, 403)
        self.cursor.execute.assert_not_called()

    def test_column_lengths_and_unknown_fields(self):
        for invalid in ({"director_id": "x" * 46}, {"director_password": ""}, {"director_phone": "1" * 21}, {"unknown": "value"}):
            self.assertEqual(self.client.post("/director", json={**self.body, **invalid}).status_code, 422)
        self.cursor.execute.assert_not_called()


if __name__ == "__main__":
    unittest.main()
