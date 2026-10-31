import unittest
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
from pydantic import ValidationError
from schemas.sell_product import SellProductUpdate
from services.sell_product_service import put_sell_product_code,get_sell_product_code

class ProductEditTests(unittest.TestCase):
    def setUp(self):
        self.db=MagicMock();self.cursor=self.db.cursor.return_value.__enter__.return_value
        self.fields=dict(sell_product_title='새 상품명',sell_product_image='/media/products/original.jpg',sell_product_contents='새 설명',sell_product_sell_price=20000)
        self.request=SellProductUpdate(**self.fields)
    def test_update_checks_locked_status_before_write(self):
        self.cursor.fetchone.return_value={'sell_product_sell_status':'판매중'}
        with patch('services.sell_product_service.get_sell_product_code',return_value='updated'):
            self.assertEqual(put_sell_product_code(self.db,self.request,'P1'),'updated')
        calls=self.cursor.execute.call_args_list
        self.assertIn('FOR UPDATE',calls[0].args[0]);self.assertIn('UPDATE sell_product',calls[1].args[0])
        self.assertEqual(calls[1].args[1],('새 상품명','/media/products/original.jpg','새 설명',20000,'P1'))
        self.db.commit.assert_called_once()
    def test_in_progress_and_completed_products_are_not_modified(self):
        for status in ('거래중','거래완료'):
            with self.subTest(status=status):
                self.db.reset_mock();self.cursor.fetchone.return_value={'sell_product_sell_status':status}
                with self.assertRaises(HTTPException) as error:put_sell_product_code(self.db,self.request,'P1')
                self.assertEqual(error.exception.status_code,409)
                self.assertEqual(self.cursor.execute.call_count,1);self.db.rollback.assert_called_once();self.db.commit.assert_not_called()
    def test_missing_product_and_update_error_rollback(self):
        self.cursor.fetchone.return_value=None
        self.assertIsNone(put_sell_product_code(self.db,self.request,'P1'));self.db.rollback.assert_called_once()
        self.db.reset_mock();self.cursor.fetchone.return_value={'sell_product_sell_status':'판매중'}
        self.cursor.execute.side_effect=[None,RuntimeError('update failure')]
        with self.assertRaises(RuntimeError):put_sell_product_code(self.db,self.request,'P1')
        self.db.rollback.assert_called_once();self.db.commit.assert_not_called()
    def test_validation_rejects_bad_prices_empty_text_and_protected_fields(self):
        for changes in ({'sell_product_sell_price':0},{'sell_product_sell_price':True},{'sell_product_sell_price':1.5},
            {'sell_product_sell_price':2147483648},{'sell_product_title':' '},{'sell_product_contents':' '},{'sell_product_grade':'A'}):
            with self.subTest(changes=changes),self.assertRaises(ValidationError):SellProductUpdate(**{**self.fields,**changes})
    def test_detail_exposes_registration_type_and_actual_owner(self):
        for sale_type in ('direct','consign'):
            with self.subTest(sale_type=sale_type):
                self.cursor.fetchone.return_value={**self.fields,'sell_product_code':'P1','sell_product_serial_code':'SV1','seq':1,'sell_product_sell_status':'판매중'}
                self.cursor.fetchall.return_value=[{'user_user_id':'owner','registration_type':sale_type}]
                result=get_sell_product_code(self.db,'P1')
                self.assertEqual(result.seller_user_id,'owner');self.assertEqual(result.sale_type,sale_type)
