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
        app = FastAPI(); app.include_router(router)
        app.dependency_overrides[get_db] = lambda: self.db
        app.dependency_overrides[get_current_account] = lambda: SimpleNamespace(role='manager', account=SimpleNamespace(manager_id='m'))
        self.client = TestClient(app)
        self.body = {'pay_pay_no':'pay1', 'manager_manager_id':'m'}
        self.pay = {'user_user_id':'owner','pay_status':'결제완료','pay_price':20000,
            'inspection_request_inspection_request_no':'20261030000001'}
        self.items = [self.item('A'),self.item('FAKE')]
        self.prepare()
    def item(self, grade, status='검수완료'):
        return {'inspect_code':'INS1','inspect_status':status,'inspect_grade':grade}
    def prepare(self, items=None, previous=None):
        self.cursor.fetchone.side_effect = [self.pay, {'manager_id':'m'}]
        self.cursor.fetchall.side_effect = [self.items if items is None else items, [] if previous is None else previous]
    def test_create_records_pay_owner_and_auto_amount_without_changing_balance(self):
        with patch('services.deposit_refund_service.datetime') as clock:
            clock.now.return_value = datetime(2026,10,28,21,10,47,123456)
            response=self.client.post('/deposit_refund',json=self.body)
        self.assertEqual(response.status_code,201,response.text)
        result=response.json()
        self.assertEqual(result['user_user_id'],'owner')
        self.assertEqual(result['deposit_refund_price'],5000)
        self.assertEqual(result['deposit_refund_no'],'pay120261028211047123456')
        calls=self.cursor.execute.call_args_list
        self.assertEqual(len(calls),5)
        self.assertIn('FOR UPDATE',calls[0].args[0])
        self.assertIn('FOR UPDATE',calls[2].args[0])
        self.assertEqual(calls[2].args[1],('20261030000001',))
        self.assertIn('INSERT INTO deposit_refund',calls[-1].args[0])
        self.assertFalse(any('UPDATE `user`' in call.args[0] or 'UPDATE pay ' in call.args[0] for call in calls))
        self.db.commit.assert_called_once()
    def test_fake_waiting_and_missing_grades_do_not_count(self):
        self.prepare([self.item('A'),self.item('B'),self.item(' fake '),self.item(None),self.item(' '),self.item('A','검수중')])
        response=self.client.post('/deposit_refund',json=self.body)
        self.assertEqual(response.status_code,201,response.text)
        self.assertEqual(response.json()['deposit_refund_price'],10000)
    def test_partial_completion_only_refunds_newly_eligible_amount(self):
        self.prepare([self.item('A'),self.item('B'),self.item('FAKE')],[{'deposit_refund_price':5000}])
        response=self.client.post('/deposit_refund',json=self.body)
        self.assertEqual(response.status_code,201,response.text)
        self.assertEqual(response.json()['deposit_refund_price'],5000)
    def test_previously_refunded_cards_cannot_be_refunded_again(self):
        self.prepare(previous=[{'deposit_refund_price':5000}])
        self.assertEqual(self.client.post('/deposit_refund',json=self.body).status_code,409)
        self.db.rollback.assert_called_once(); self.db.commit.assert_not_called()
    def test_no_eligible_cards_is_not_recorded_as_zero_refund(self):
        for items in ([],[self.item('FAKE')],[self.item(None)],[self.item('A','검수대기')]):
            with self.subTest(items=items):
                self.db.reset_mock();self.prepare(items)
                self.assertEqual(self.client.post('/deposit_refund',json=self.body).status_code,409)
                self.db.rollback.assert_called_once();self.db.commit.assert_not_called()
    def test_unpaid_or_invalid_paid_amount_cannot_be_refunded(self):
        for status,price in [('결제대기',20000),('결제완료',None),('결제완료',1000)]:
            with self.subTest(status=status,price=price):
                self.db.reset_mock();self.pay.update(pay_status=status,pay_price=price);self.prepare()
                self.assertEqual(self.client.post('/deposit_refund',json=self.body).status_code,409)
                self.db.rollback.assert_called_once();self.db.commit.assert_not_called()
    def test_missing_pay_or_manager_rolls_back(self):
        for rows in ([None],[self.pay,None]):
            with self.subTest(rows=rows):
                self.db.reset_mock();self.cursor.fetchone.side_effect=rows
                self.assertEqual(self.client.post('/deposit_refund',json=self.body).status_code,404)
                self.db.rollback.assert_called_once();self.db.commit.assert_not_called()
    def test_max_payment_number_fits_refund_key_and_detail_lookup(self):
        self.body['pay_pay_no']='9'*64
        response=self.client.post('/deposit_refund',json=self.body)
        self.assertEqual(response.status_code,201,response.text)
        refund=response.json();self.assertEqual(len(refund['deposit_refund_no']),84)
        self.cursor.fetchone.side_effect=None;self.cursor.fetchone.return_value=refund
        detail=self.client.get('/deposit_refund/'+refund['deposit_refund_no'],params={'user_user_id':'owner','pay_pay_no':self.body['pay_pay_no']})
        self.assertEqual(detail.json(),refund)
    def test_failed_insert_rolls_back(self):
        self.cursor.execute.side_effect=[None,None,None,None,RuntimeError('insert failure')]
        with self.assertRaises(RuntimeError):self.client.post('/deposit_refund',json=self.body)
        self.db.rollback.assert_called_once();self.db.commit.assert_not_called()
    def test_manual_price_and_owner_are_rejected(self):
        for price in (0,-1,5000,0.5,True,2147483648):
            with self.subTest(price=price):
                self.assertEqual(self.client.post('/deposit_refund',json={**self.body,'deposit_refund_price':price}).status_code,422)
        self.assertEqual(self.client.post('/deposit_refund',json={**self.body,'user_user_id':'another'}).status_code,422)
        self.db.begin.assert_not_called()
    def test_detail_uses_all_primary_key_fields(self):
        self.cursor.fetchone.side_effect=None;self.cursor.fetchone.return_value=None
        self.assertEqual(self.client.get('/deposit_refund/dr1?user_user_id=u&pay_pay_no=p').status_code,404)
        self.assertEqual(self.cursor.execute.call_args.args[1],('dr1','u','p'))
        self.assertEqual(self.client.get('/deposit_refund/dr1').status_code,422)
    def test_empty_list_paging(self):
        self.cursor.fetchall.side_effect=None;self.cursor.fetchall.return_value=[]
        self.assertEqual(self.client.get('/deposit_refund?limit=5&offset=10').json(),[])
        self.assertEqual(self.cursor.execute.call_args.args[1],(5,10))

    def test_pay_filter_keeps_owner_restriction(self):
        from services.deposit_refund_service import get_deposit_refunds
        self.cursor.fetchall.side_effect = None
        self.cursor.fetchall.return_value = []
        get_deposit_refunds(self.db, user_id='owner', pay_no='pay1')
        sql, params = self.cursor.execute.call_args.args
        self.assertIn('user_user_id = %s AND pay_pay_no = %s', sql)
        self.assertEqual(params, ('owner', 'pay1', 20, 0))
