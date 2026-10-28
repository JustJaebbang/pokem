import unittest
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from database import get_db
from dependencies import get_current_account
from routers.deposit_refund import router


class DepositRefundTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_db] = lambda: self.db
        app.dependency_overrides[get_current_account] = lambda: SimpleNamespace(role="manager", account=SimpleNamespace(manager_id="m"))
        self.client = TestClient(app)
        self.body = {"pay_pay_no": "pay1", "manager_manager_id": "m", "deposit_refund_price": 3000}

    def test_create_records_pay_owner_without_updating_balance_or_payment(self):
        self.cursor.fetchone.side_effect = [{"user_user_id": "owner"}, {"manager_id": "m"}]
        with patch("services.deposit_refund_service.datetime") as clock:
            clock.now.return_value = datetime(2026, 10, 28, 21, 10, 47, 123456)
            response = self.client.post("/deposit_refund", json=self.body)
        self.assertEqual(response.status_code, 201)
        result = response.json()
        self.assertEqual(result["user_user_id"], "owner")
        self.assertEqual(result["deposit_refund_price"], 3000)
        self.assertEqual(result["deposit_refund_no"], "pay120261028")
        self.assertEqual(result["deposit_refund_date"], "2026-10-28 21:10:47")
        calls = self.cursor.execute.call_args_list
        self.assertEqual(len(calls), 3)
        self.assertIn("INSERT INTO deposit_refund", calls[2].args[0])
        self.db.commit.assert_called_once()
        self.db.rollback.assert_not_called()

    def test_missing_pay_or_manager_rolls_back_without_inserting(self):
        for rows in ([None], [{"user_user_id": "owner"}, None]):
            with self.subTest(rows=rows):
                self.db.reset_mock()
                self.cursor.fetchone.side_effect = rows
                self.assertEqual(self.client.post("/deposit_refund", json=self.body).status_code, 404)
                self.db.rollback.assert_called_once()
                self.db.commit.assert_not_called()

    def test_max_length_payment_number_can_be_used_for_detail_lookup(self):
        self.body["pay_pay_no"] = "9" * 64
        self.cursor.fetchone.side_effect = [{"user_user_id": "owner"}, {"manager_id": "m"}]
        response = self.client.post("/deposit_refund", json=self.body)
        self.assertEqual(response.status_code, 201)
        refund = response.json()
        self.assertEqual(len(refund["deposit_refund_no"]), 72)
        self.cursor.fetchone.side_effect = None
        self.cursor.fetchone.return_value = refund
        detail = self.client.get(
            "/deposit_refund/" + refund["deposit_refund_no"],
            params={"user_user_id": "owner", "pay_pay_no": self.body["pay_pay_no"]},
        )
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(detail.json(), refund)

    def test_failed_insert_rolls_back(self):
        self.cursor.fetchone.side_effect = [{"user_user_id": "owner"}, {"manager_id": "m"}]
        self.cursor.execute.side_effect = [None, None, RuntimeError("insert failure")]
        with self.assertRaises(RuntimeError):
            self.client.post("/deposit_refund", json=self.body)
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_price_and_unknown_fields_are_validated(self):
        for price in (0, -1, 0.5, True, 2147483648):
            with self.subTest(price=price):
                self.assertEqual(self.client.post("/deposit_refund", json={**self.body, "deposit_refund_price": price}).status_code, 422)
        self.assertEqual(self.client.post("/deposit_refund", json={**self.body, "user_user_id": "another"}).status_code, 422)
        self.db.begin.assert_not_called()

    def test_detail_uses_all_three_primary_key_fields(self):
        self.cursor.fetchone.return_value = None
        response = self.client.get("/deposit_refund/dr1?user_user_id=u&pay_pay_no=p")
        self.assertEqual(response.status_code, 404)
        self.assertEqual(self.cursor.execute.call_args.args[1], ("dr1", "u", "p"))
        self.assertEqual(self.client.get("/deposit_refund/dr1").status_code, 422)

    def test_list_returns_empty_list_with_pagination(self):
        self.cursor.fetchall.return_value = []
        response = self.client.get("/deposit_refund?limit=5&offset=10")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), [])
        self.assertEqual(self.cursor.execute.call_args.args[1], (5, 10))


if __name__ == "__main__":
    unittest.main()
