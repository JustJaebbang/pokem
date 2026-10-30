import unittest
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from database import get_db
from dependencies import get_current_account
from routers.delivery import router


class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.current = SimpleNamespace(role="manager", account=SimpleNamespace(manager_id="manager1"))
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_db] = lambda: self.db
        app.dependency_overrides[get_current_account] = lambda: self.current
        self.client = TestClient(app)
        self.body = {
            "purchase_item_code": "purchase1",
            "delivery_company_delivery_company_code": "company1",
        }

    def prepare_creation(self, existing=None, seq=1):
        self.cursor.fetchone.side_effect = [
            {"user_user_id": "buyer1", "sell_product_sell_product_code": "product1"}, {"manager_id": "manager1"},
            {"delivery_company_code": "company1"}, existing, {"last_seq": seq},
        ]

    def test_create_uses_buyer_manager_and_daily_number(self):
        self.prepare_creation(seq=42)
        with patch("services.delivery_service.datetime") as clock:
            clock.now.return_value = datetime(2026, 10, 29, 12, 30)
            response = self.client.post("/delivery", json=self.body)
        self.assertEqual(response.status_code, 201)
        row = response.json()
        self.assertEqual(row["delivery_no"], "20261029000042")
        self.assertEqual(row["user_user_id"], "buyer1")
        self.assertEqual(row["manager_manager_id"], "manager1")
        self.db.commit.assert_called_once()

    def test_duplicate_and_sequence_overflow_roll_back(self):
        for existing, seq in [({"delivery_no": "existing"}, 1), (None, 1000000)]:
            with self.subTest(existing=existing, seq=seq):
                self.db.reset_mock()
                self.prepare_creation(existing, seq)
                self.assertEqual(self.client.post("/delivery", json=self.body).status_code, 409)
                self.db.rollback.assert_called_once()
                self.db.commit.assert_not_called()

    def test_missing_purchase_is_rejected(self):
        self.prepare_creation()
        self.cursor.fetchone.side_effect = [None]
        self.assertEqual(self.client.post("/delivery", json=self.body).status_code, 404)
        self.db.rollback.assert_called_once()

    def test_users_cannot_create_or_read_other_buyers_delivery(self):
        self.current = SimpleNamespace(role="user", account=SimpleNamespace(user_id="buyer2"))
        self.assertEqual(self.client.post("/delivery", json=self.body).status_code, 403)
        self.cursor.fetchone.return_value = None
        self.assertEqual(self.client.get("/delivery/20261029000001").status_code, 404)
        self.assertEqual(self.cursor.execute.call_args.args[1], ("20261029000001", "buyer2"))

    def test_manager_impersonation_and_buyer_override_are_rejected(self):
        self.assertEqual(self.client.post("/delivery", json={**self.body, "manager_manager_id": "other"}).status_code, 403)
        self.assertEqual(self.client.post("/delivery", json={**self.body, "user_user_id": "other"}).status_code, 422)


if __name__ == "__main__":
    unittest.main()
