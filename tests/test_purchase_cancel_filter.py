import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock
from services.purchase_cancel_service import get_purchase_cancel

class CancelFilterTests(unittest.TestCase):
    def test_purchase_filter_keeps_buyer_or_seller_visibility(self):
        db=MagicMock();cursor=db.cursor.return_value.__enter__.return_value
        cursor.fetchall.return_value=[]
        current=SimpleNamespace(role='user',account=SimpleNamespace(user_id='buyer'))
        self.assertEqual(get_purchase_cancel(db,current,purchase_code='PI1'),[])
        sql,params=cursor.execute.call_args.args
        self.assertIn('pc.purchase_item_purchase_item_code = %s',sql)
        self.assertIn('(pc.user_user_id = %s OR po.user_user_id = %s)',sql)
        self.assertEqual(params,('PI1','buyer','buyer'))
