import unittest
from unittest.mock import MagicMock
from fastapi import HTTPException
from services.pay_service import complete_pay

class PayCompleteTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.cursor.rowcount = 1
        self.row = dict(pay_no='PAY1', pay_status='결제대기', pay_price=15000,
            pay_date='2026-10-30 12:00:00', user_user_id='owner', manager_manager_id='manager',
            inspection_request_inspection_request_no='20261030000001')
        self.cursor.fetchone.return_value = self.row
    def test_completes_without_changing_balance_amount_or_creation_time(self):
        result = complete_pay(self.db, 'PAY1', 'owner', 15000)
        self.assertEqual(result.pay_status, '결제완료')
        self.assertEqual(result.pay_price, 15000)
        self.assertEqual(result.pay_date, self.row['pay_date'])
        calls = self.cursor.execute.call_args_list
        self.assertIn('FOR UPDATE', calls[0].args[0])
        self.assertEqual(calls[1].args[1], ('결제완료', 'PAY1', '결제대기'))
        self.assertEqual(len(calls), 2)
        self.db.commit.assert_called_once()
    def test_repeated_completion_has_no_write(self):
        self.row['pay_status'] = '결제완료'
        self.assertEqual(complete_pay(self.db, 'PAY1', 'owner', 15000).pay_status, '결제완료')
        self.assertEqual(self.cursor.execute.call_count, 1)
    def test_missing_other_owner_invalid_state_and_price_change_rollback(self):
        for row, price, status in [(None,15000,404), ({**self.row,'user_user_id':'other'},15000,403),
            ({**self.row,'pay_status':'취소'},15000,409), ({**self.row,'pay_price':None},15000,409),
            (dict(self.row),10000,409)]:
            with self.subTest(status=status):
                self.db.reset_mock(); self.cursor.fetchone.return_value=row
                with self.assertRaises(HTTPException) as error: complete_pay(self.db, 'PAY1', 'owner', price)
                self.assertEqual(error.exception.status_code,status)
                self.db.rollback.assert_called_once(); self.db.commit.assert_not_called()
    def test_zero_price_is_valid(self):
        self.row['pay_price']=0
        self.assertEqual(complete_pay(self.db,'PAY1','owner',0).pay_status,'결제완료')
