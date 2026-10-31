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
        self.addCleanup(self.client.close)
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
        self.assertEqual(row["purchase_item_code"], "purchase1")
        self.assertIsNone(row["return_no"])
        self.assertIsNone(row["inspect_inspect_code"])
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

    def test_return_delivery_uses_return_user_and_inspect(self):
        self.prepare_creation(seq=43)
        self.cursor.fetchone.side_effect = [
            {"user_user_id": "return_owner", "inspect_inspect_code": "inspect1"},
            {"manager_id": "manager1"}, {"delivery_company_code": "company1"}, None, {"last_seq": 43},
        ]
        body = {"return_no": "return1", "delivery_company_delivery_company_code": "company1"}
        response = self.client.post("/delivery", json=body)
        self.assertEqual(response.status_code, 201)
        row = response.json()
        self.assertEqual(row["return_no"], "return1")
        self.assertIsNone(row["purchase_item_code"])
        self.assertEqual(row["user_user_id"], "return_owner")
        self.assertIsNone(row["sell_product_sell_product_code"])
        self.assertEqual(row["inspect_inspect_code"], "inspect1")
        self.assertIn("FROM `return` WHERE return_no", self.cursor.execute.call_args_list[0].args[0])
        self.assertEqual(self.cursor.execute.call_args.args[1][-2:], (None, "return1"))
        self.db.commit.assert_called_once()

    def test_exactly_one_source_is_required(self):
        for sources in ({}, {"purchase_item_code": None, "return_no": None},
                        {"purchase_item_code": "purchase1", "return_no": "return1"},
                        {"return_no": ""}, {"return_no": "r" * 65}):
            with self.subTest(sources=sources):
                body = {"delivery_company_delivery_company_code": "company1", **sources}
                self.assertEqual(self.client.post("/delivery", json=body).status_code, 422)
        self.cursor.execute.assert_not_called()

    def test_missing_return_is_rejected(self):
        self.cursor.fetchone.return_value = None
        response = self.client.post("/delivery", json={"return_no": "missing", "delivery_company_delivery_company_code": "company1"})
        self.assertEqual(response.status_code, 404)
        self.assertIn("반송", response.json()["detail"])
        self.db.rollback.assert_called_once()

    def test_return_without_inspect_is_rejected(self):
        self.cursor.fetchone.return_value = {"user_user_id": "return_owner", "inspect_inspect_code": None}
        response = self.client.post("/delivery", json={"return_no": "legacy", "delivery_company_delivery_company_code": "company1"})
        self.assertEqual(response.status_code, 409)
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_duplicate_return_rolls_back(self):
        self.prepare_creation(existing={"delivery_no": "existing"})
        self.cursor.fetchone.side_effect = [
            {"user_user_id": "return_owner", "inspect_inspect_code": "inspect1"},
            {"manager_id": "manager1"}, {"delivery_company_code": "company1"}, {"delivery_no": "existing"},
        ]
        response = self.client.post("/delivery", json={"return_no": "return1", "delivery_company_delivery_company_code": "company1"})
        self.assertEqual(response.status_code, 409)
        self.assertIn("return_return_no", self.cursor.execute.call_args_list[-1].args[0])
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_return_owner_reads_detail_and_list(self):
        self.current = SimpleNamespace(role="user", account=SimpleNamespace(user_id="return_owner"))
        row = {"delivery_no": "delivery1", "return_no": "return1", "purchase_item_code": None,
               "user_user_id": "return_owner", "sell_product_sell_product_code": None, "inspect_inspect_code": "inspect1",
               "manager_manager_id": "manager1", "delivery_company_delivery_company_code": "company1"}
        self.cursor.fetchone.return_value = row
        response = self.client.get("/delivery/delivery1")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["return_no"], "return1")
        self.assertIn("COALESCE(p.user_user_id, r.user_user_id) = %s", self.cursor.execute.call_args.args[0])
        self.assertEqual(self.cursor.execute.call_args.args[1], ("delivery1", "return_owner"))
        self.cursor.fetchall.return_value = [row]
        self.assertEqual(self.client.get("/delivery").json()[0]["return_no"], "return1")
        self.assertEqual(self.cursor.execute.call_args.args[1], ("return_owner", 20, 0))

    def delivery_row(self, status):
        return {
            "delivery_no": "delivery1",
            "delivery_date": "2026-10-31 10:00:00",
            "delivery_status": status,
            "purchase_item_code": "purchase1",
            "return_no": None,
            "user_user_id": "buyer1",
            "manager_manager_id": "manager1",
            "delivery_company_delivery_company_code": "company1",
            "sell_product_sell_product_code": "product1",
            "inspect_inspect_code": None,
        }

    def test_manager_updates_delivery_status_in_order(self):
        self.cursor.fetchone.side_effect = [
            {"delivery_status": "배송준비"},
            self.delivery_row("배송중"),
        ]
        self.cursor.rowcount = 1

        response = self.client.patch(
            "/delivery/delivery1/status",
            json={"delivery_status": "배송중"},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["delivery_status"], "배송중")
        update = self.cursor.execute.call_args_list[1]
        self.assertIn("UPDATE delivery SET delivery_status", update.args[0])
        self.assertEqual(update.args[1], ("배송중", "delivery1", "배송준비"))
        self.db.commit.assert_called_once()

    def test_status_update_is_idempotent_but_rejects_skips_and_invalid_values(self):
        self.cursor.fetchone.side_effect = [
            {"delivery_status": "배송중"},
            self.delivery_row("배송중"),
        ]
        response = self.client.patch(
            "/delivery/delivery1/status",
            json={"delivery_status": "배송중"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["delivery_status"], "배송중")
        self.assertFalse(any("UPDATE delivery SET" in call.args[0] for call in self.cursor.execute.call_args_list))

        self.db.reset_mock()
        self.cursor.fetchone.side_effect = None
        self.cursor.fetchone.return_value = {"delivery_status": "배송준비"}
        response = self.client.patch(
            "/delivery/delivery1/status",
            json={"delivery_status": "배송완료"},
        )
        self.assertEqual(response.status_code, 409)
        self.db.rollback.assert_called_once()

        response = self.client.patch(
            "/delivery/delivery1/status",
            json={"delivery_status": "분실"},
        )
        self.assertEqual(response.status_code, 422)

    def test_status_update_requires_manager_and_existing_delivery(self):
        self.current = SimpleNamespace(role="user", account=SimpleNamespace(user_id="buyer1"))
        response = self.client.patch(
            "/delivery/delivery1/status",
            json={"delivery_status": "배송중"},
        )
        self.assertEqual(response.status_code, 403)

        self.current = SimpleNamespace(role="manager", account=SimpleNamespace(manager_id="manager1"))
        self.cursor.fetchone.return_value = None
        response = self.client.patch(
            "/delivery/missing/status",
            json={"delivery_status": "배송중"},
        )
        self.assertEqual(response.status_code, 404)
        self.db.rollback.assert_called_once()


if __name__ == "__main__":
    unittest.main()
