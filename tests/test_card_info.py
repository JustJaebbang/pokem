import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock

from fastapi import FastAPI
from fastapi.testclient import TestClient
from pymysql.err import IntegrityError

from database import get_db
from dependencies import get_current_account
from routers.card_info import router


class CardInfoTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.current = SimpleNamespace(
            role="director", account=SimpleNamespace(director_id="director1")
        )
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_db] = lambda: self.db
        app.dependency_overrides[get_current_account] = lambda: self.current
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def test_director_creates_catalog_with_server_owned_sequences(self):
        response = self.client.post(
            "/card_info",
            json={
                "cardinfo_serial_code": "J_m6a_010_103_C",
                "cardinfo_category": "카드",
                "cardinfo_brand": "포켓몬",
                "cardinfo_standard": "63 × 88 mm",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        self.assertEqual(response.json()["cardinfo_last_sell_seq"], 0)
        self.assertEqual(response.json()["cardinfo_last_inspect_seq"], 0)
        self.assertEqual(
            self.cursor.execute.call_args.args[1],
            ("J_m6a_010_103_C", "카드", "포켓몬", "63 × 88 mm"),
        )
        self.db.commit.assert_called_once()

    def test_manager_and_user_cannot_change_catalog(self):
        for role in ("manager", "user"):
            self.current.role = role
            response = self.client.post(
                "/card_info",
                json={
                    "cardinfo_serial_code": "SERIAL",
                    "cardinfo_brand": "포켓몬",
                    "cardinfo_standard": "63 × 88 mm",
                },
            )
            self.assertEqual(response.status_code, 403)
        self.cursor.execute.assert_not_called()

    def test_duplicate_and_invalid_values(self):
        self.cursor.execute.side_effect = IntegrityError(1062, "duplicate")
        response = self.client.post(
            "/card_info",
            json={
                "cardinfo_serial_code": "SERIAL",
                "cardinfo_brand": "포켓몬",
                "cardinfo_standard": "63 × 88 mm",
            },
        )
        self.assertEqual(response.status_code, 409)
        self.db.rollback.assert_called_once()

        self.cursor.execute.reset_mock(side_effect=True)
        for body in (
            {},
            {"cardinfo_serial_code": " ", "cardinfo_brand": "포켓몬", "cardinfo_standard": "규격"},
            {"cardinfo_serial_code": "SERIAL", "cardinfo_brand": "", "cardinfo_standard": "규격"},
            {"cardinfo_serial_code": "SERIAL", "cardinfo_brand": "포켓몬", "cardinfo_standard": "규격", "cardinfo_last_sell_seq": 3},
        ):
            self.assertEqual(self.client.post("/card_info", json=body).status_code, 422)


if __name__ == "__main__":
    unittest.main()
