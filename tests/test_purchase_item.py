import unittest
from datetime import datetime
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from fastapi.testclient import TestClient

from database import get_db
from main import app
from schemas.purchase_item import PurchaseItemCreate, PurchaseItemResponse
from services.purchase_item_service import create_purchase_item, get_purchase_item, get_purchase_item_code


class PurchaseItemTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.request = PurchaseItemCreate(user_user_id="buyer", sell_product_sell_product_code="product")
        self.cursor.fetchone.side_effect = [{"user_id": "buyer"}, {"sell_product_sell_status": "판매중"}, None]
        self.cursor.fetchall.return_value = [{"user_user_id": "seller", "post_item_complete_date": None}]

    def test_purchase_sets_in_progress_without_completing_trade(self):
        result = create_purchase_item(self.db, self.request)
        prefix = self.request.sell_product_sell_product_code + "_"
        self.assertTrue(result.purchase_item_code.startswith(prefix))
        timestamp = result.purchase_item_code[len(prefix):]
        self.assertEqual(len(timestamp), 20)
        code_date = datetime.strptime(timestamp, "%Y%m%d%H%M%S%f")
        purchase_date = datetime.fromisoformat(result.purchase_item_date)
        self.assertEqual(code_date.replace(microsecond=0), purchase_date.replace(tzinfo=None))
        self.assertTrue(result.purchase_item_date.endswith("+09:00"))
        calls = self.cursor.execute.call_args_list
        for call in calls[:4]:
            self.assertIn("FOR UPDATE", call.args[0])
        self.assertIn("INSERT INTO purchase_item", calls[4].args[0])
        self.assertEqual(calls[4].args[1], (result.purchase_item_code, "buyer", result.purchase_item_date, "product"))
        self.assertEqual(calls[5].args[1], ("거래중", "product"))
        self.assertEqual(len(calls), 6)
        for call in calls:
            self.assertNotIn("UPDATE post_item", call.args[0])
        self.db.begin.assert_called_once()
        self.db.commit.assert_called_once()
        self.db.rollback.assert_not_called()

    def test_rejected_purchases_never_commit(self):
        cases = [
            ([None], [], 404),
            ([{"user_id": "buyer"}, None], [], 404),
            ([{"user_id": "buyer"}, {"sell_product_sell_status": "판매완료"}], [], 409),
            ([{"user_id": "buyer"}, {"sell_product_sell_status": "판매중"}], [], 409),
            ([{"user_id": "buyer"}, {"sell_product_sell_status": "판매중"}], [{"user_user_id": "buyer", "post_item_complete_date": None}], 409),
            ([{"user_id": "buyer"}, {"sell_product_sell_status": "판매중"}], [{"user_user_id": "seller", "post_item_complete_date": "done"}], 409),
            ([{"user_id": "buyer"}, {"sell_product_sell_status": "판매중"}, {"purchase_item_code": "existing"}], [{"user_user_id": "seller", "post_item_complete_date": None}], 409),
        ]
        for rows, posts, status in cases:
            with self.subTest(rows=rows, posts=posts):
                self.setUp()
                self.cursor.fetchone.side_effect = rows
                self.cursor.fetchall.return_value = posts
                with self.assertRaises(HTTPException) as error:
                    create_purchase_item(self.db, self.request)
                self.assertEqual(error.exception.status_code, status)
                self.db.rollback.assert_called_once()
                self.db.commit.assert_not_called()
                for call in self.cursor.execute.call_args_list:
                    self.assertNotIn("INSERT INTO", call.args[0])

    def test_each_write_failure_rolls_back(self):
        for write_index in (4, 5):
            with self.subTest(write_index=write_index):
                self.setUp()
                self.cursor.execute.side_effect = [None] * write_index + [RuntimeError("write failed")]
                with self.assertRaises(RuntimeError):
                    create_purchase_item(self.db, self.request)
                self.db.rollback.assert_called_once()
                self.db.commit.assert_not_called()

    def test_list_empty_and_missing_user(self):
        self.cursor.fetchone.side_effect = None
        self.cursor.fetchone.return_value = {"user_id": "buyer"}
        self.cursor.fetchall.return_value = []
        self.assertEqual(get_purchase_item(self.db, "buyer"), [])
        self.cursor.fetchone.return_value = None
        with self.assertRaises(HTTPException):
            get_purchase_item(self.db, "missing")

    def test_missing_purchase(self):
        self.cursor.fetchone.side_effect = None
        self.cursor.fetchone.return_value = None
        self.assertIsNone(get_purchase_item_code(self.db, "missing"))

    def test_http_contract(self):
        result = PurchaseItemResponse(purchase_item_code="PI_test", user_user_id="buyer", purchase_item_date="date", sell_product_sell_product_code="product")
        app.dependency_overrides[get_db] = lambda: self.db
        try:
            with TestClient(app) as client:
                with patch("routers.purchase_item.purchase_item_service.create_purchase_item", return_value=result):
                    response = client.post("/purchase_item", json=self.request.model_dump())
                    self.assertEqual(response.status_code, 201)
                    self.assertEqual(response.json(), result.model_dump())
                self.assertEqual(client.post("/purchase_item", json={}).status_code, 422)
                with patch("routers.purchase_item.purchase_item_service.get_purchase_item_code", return_value=None):
                    self.assertEqual(client.get("/purchase_item/missing").status_code, 404)
                with patch("routers.purchase_item.purchase_item_service.get_purchase_item", return_value=[]):
                    self.assertEqual(client.get("/purchase_item", params={"user_id": "buyer"}).json(), [])
        finally:
            app.dependency_overrides.clear()


if __name__ == "__main__":
    unittest.main()
