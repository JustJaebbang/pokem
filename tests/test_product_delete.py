import unittest
from unittest.mock import MagicMock
from fastapi import HTTPException
from pymysql.err import IntegrityError
from services.sell_product_service import delete_sell_product_code

class ProductDeleteTests(unittest.TestCase):
    def setUp(self):
        self.db=MagicMock()
        self.cursor=self.db.cursor.return_value.__enter__.return_value
        self.product=dict(sell_product_code="P1",sell_product_serial_code="SV1",seq=1,
            sell_product_title="title",sell_product_image="",sell_product_contents="description",
            sell_product_sell_price=10000,sell_product_grade="Unrank",sell_product_sell_status="판매중")
        self.cursor.fetchone.return_value=self.product
    def test_delete_checks_locked_status_and_commits(self):
        result=delete_sell_product_code(self.db,"P1")
        self.assertEqual(result["sell_product_code"],"P1")
        calls=self.cursor.execute.call_args_list
        self.assertIn("FOR UPDATE",calls[0].args[0])
        self.assertEqual(calls[0].args[1],("P1",))
        self.assertIn("DELETE",calls[1].args[0])
        self.assertEqual(calls[1].args[1],("P1",))
        self.db.commit.assert_called_once()
    def test_in_progress_completed_and_returning_products_cannot_be_deleted(self):
        for status in ["거래중","거래완료","반환대기"]:
            with self.subTest(status=status):
                self.db.reset_mock()
                self.cursor.fetchone.return_value={**self.product,"sell_product_sell_status":status}
                with self.assertRaises(HTTPException) as e: delete_sell_product_code(self.db,"P1")
                self.assertEqual(e.exception.status_code,409)
                self.assertEqual(self.cursor.execute.call_count,1)
                self.db.commit.assert_not_called()
                self.db.rollback.assert_called_once()
    def test_foreign_key_conflict_is_409_and_rolls_back(self):
        self.cursor.execute.side_effect=[None,IntegrityError(1451,"linked")]
        with self.assertRaises(HTTPException) as e: delete_sell_product_code(self.db,"P1")
        self.assertEqual(e.exception.status_code,409)
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()
    def test_missing_returns_none_without_delete(self):
        self.cursor.fetchone.return_value=None
        self.assertIsNone(delete_sell_product_code(self.db,"P1"))
        self.assertEqual(self.cursor.execute.call_count,1)
        self.db.commit.assert_not_called()
