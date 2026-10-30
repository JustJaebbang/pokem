import unittest
from unittest.mock import MagicMock
from fastapi import HTTPException
from pydantic import ValidationError
from schemas.purchase_item import PurchaseItemCreate
from services.purchase_item_service import create_purchase_item

class PurchasePriceTests(unittest.TestCase):
    def test_price_change_rolls_back_before_deduction(self):
        db = MagicMock()
        cursor = db.cursor.return_value.__enter__.return_value
        cursor.fetchone.side_effect = [
            {'user_id': 'buyer', 'user_money': 30000},
            {'sell_product_sell_status': '판매중', 'sell_product_sell_price': 20000},
        ]
        request = PurchaseItemCreate(user_user_id='buyer', sell_product_sell_product_code='P-1', expected_price=10000)
        with self.assertRaises(HTTPException) as error:
            create_purchase_item(db, request)
        self.assertEqual(error.exception.status_code, 409)
        db.rollback.assert_called_once()
        db.commit.assert_not_called()
        self.assertFalse(any('INSERT' in call.args[0] for call in cursor.execute.call_args_list))
    def test_expected_price_is_optional_but_strict(self):
        fields = dict(user_user_id='buyer', sell_product_sell_product_code='P-1')
        self.assertIsNone(PurchaseItemCreate(**fields).expected_price)
        for value in [-1, True, '100', 1.5]:
            with self.subTest(value=value), self.assertRaises(ValidationError):
                PurchaseItemCreate(**fields, expected_price=value)
