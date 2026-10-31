import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock

from fastapi import FastAPI
from fastapi.testclient import TestClient

from database import get_db
from dependencies import get_current_account
from routers.pay import router


class PayApiTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.pay = {
            "pay_no": "2026102800000120261028203045", "pay_status": "결제대기",
            "pay_price": 15000, "pay_date": "2026-10-28 20:30:45",
            "user_user_id": "u", "manager_manager_id": "m",
            "inspection_request_inspection_request_no": "20261028000001",
        }
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_db] = lambda: self.db
        app.dependency_overrides[get_current_account] = lambda: SimpleNamespace(role="manager", account=SimpleNamespace(manager_id="m"))
        self.client = TestClient(app)

    def test_list_has_bounded_pagination(self):
        self.cursor.fetchall.return_value = [self.pay]
        response = self.client.get("/pay?limit=5&offset=10")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), [self.pay])
        self.assertEqual(self.cursor.execute.call_args.args[1], (5, 10))
        self.assertEqual(self.client.get("/pay?limit=101").status_code, 422)

    def test_missing_detail_is_404(self):
        self.cursor.fetchone.return_value = None
        self.assertEqual(self.client.get("/pay/missing").status_code, 404)

    def test_patch_changes_only_supplied_field_even_when_value_unchanged(self):
        self.cursor.fetchone.side_effect = [{"pay_no": self.pay["pay_no"]}, self.pay]
        self.cursor.rowcount = 0
        response = self.client.patch("/pay/" + self.pay["pay_no"], json={"pay_status": "결제대기"})
        self.assertEqual(response.status_code, 200)
        update = self.cursor.execute.call_args_list[1]
        self.assertIn("SET pay_status = %s WHERE", update.args[0])
        self.assertEqual(update.args[1], ("결제대기", self.pay["pay_no"]))
        self.db.commit.assert_called_once()

    def test_invalid_changes_are_rejected_before_accessing_db(self):
        for body in ({}, {"pay_price": None}, {"pay_price": -1}, {"pay_price": 10000},
                     {"user_user_id": "another"}, {"pay_status": " "}):
            with self.subTest(body=body):
                self.assertEqual(self.client.patch("/pay/123", json=body).status_code, 422)
        self.db.begin.assert_not_called()

    def test_missing_update_rolls_back(self):
        self.cursor.fetchone.return_value = None
        self.assertEqual(self.client.patch("/pay/missing", json={"pay_status": "결제완료"}).status_code, 404)
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_update_failure_rolls_back(self):
        self.cursor.fetchone.return_value = {"pay_no": self.pay["pay_no"]}
        self.cursor.execute.side_effect = [None, RuntimeError("failure")]
        with self.assertRaises(RuntimeError):
            self.client.patch("/pay/123", json={"pay_status": "결제완료"})
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()


if __name__ == "__main__":
    unittest.main()
