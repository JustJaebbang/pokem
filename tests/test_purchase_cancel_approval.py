import unittest
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
from services import purchase_cancel_service as service


class CancelApprovalTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.cursor.fetchone.return_value = {"purchase_item_purchase_item_code": "BUY1"}
        self.cursor.rowcount = 1
        self.cancel = dict(purchase_cancel_code="C1", purchase_item_purchase_item_code="BUY1",
            user_user_id="buyer", purchase_cancel_date="2026-10-31", purchase_cancel_reason="취소",
            purchase_cancel_status="요청중")
        self.trade = ({"purchase_item_status": "취소요청"},
            {"sell_product_code": "P1", "sell_product_sell_status": "거래중"},
            {"cybermoney_pay_code": "PAY1", "cybermoney_pay_price": 10000},
            {"user_id": "buyer", "user_money": 500}, "seller")
        self.lock_trade = self.enterContext(patch.object(service, "_lock_trade", return_value=self.trade))
        self.enterContext(patch.object(service, "_lock_cancel", return_value=self.cancel))
        self.enterContext(patch.object(service, "_assert_unpaid_to_seller"))

    def writes(self):
        return [(" ".join(c.args[0].split()), c.args[1]) for c in self.cursor.execute.call_args_list
                if c.args[0].strip().startswith(("UPDATE", "INSERT"))]

    def test_approve_restores_listing_and_keeps_canceled_purchase_in_same_transaction(self):
        result = service.process_purchase_cancel(self.db, "C1", "seller", "approve")
        self.assertEqual(result.purchase_cancel_status, "승인")
        writes = self.writes()
        self.assertEqual(len(writes), 6)
        self.assertEqual(next(p for q,p in writes if q.startswith("UPDATE `user`")), (10000, "buyer"))
        self.assertEqual(next(p for q,p in writes if q.startswith("UPDATE sell_product")), ("판매중", "P1", "거래중"))
        self.assertEqual(next(p for q,p in writes if q.startswith("UPDATE purchase_item")), ("거래취소", "BUY1", "취소요청"))
        self.assertEqual(next(p for q,p in writes if q.startswith("UPDATE cybermoney_pay ")), ("결제취소", "PAY1", "결제완료"))
        self.assertFalse(any(q.startswith("DELETE") for q,p in writes))
        self.db.begin.assert_called_once()
        self.db.commit.assert_called_once()
        self.db.rollback.assert_not_called()

    def test_reject_and_withdraw_do_not_refund_or_restore_listing(self):
        for action, actor, status in [("reject", "seller", "거절"), ("withdraw", "buyer", "철회")]:
            with self.subTest(action=action):
                self.db.reset_mock()
                result = service.process_purchase_cancel(self.db, "C1", actor, action)
                self.assertEqual(result.purchase_cancel_status, status)
                writes = self.writes()
                self.assertEqual(len(writes), 2)
                self.assertEqual(writes[0][1], ("거래중", "BUY1", "취소요청"))
                self.assertFalse(any("sell_product" in q or "cybermoney" in q or "UPDATE `user`" in q for q,p in writes))
                self.db.commit.assert_called_once()

    def test_failure_restoring_listing_rolls_back_refund_and_all_other_writes(self):
        def execute(query, params):
            self.cursor.rowcount = 0 if "UPDATE sell_product" in query else 1
        self.cursor.execute.side_effect = execute
        with self.assertRaises(HTTPException):
            service.process_purchase_cancel(self.db, "C1", "seller", "approve")
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_repeated_approval_does_not_refund_again(self):
        self.cancel["purchase_cancel_status"] = "승인"
        with self.assertRaises(HTTPException):
            service.process_purchase_cancel(self.db, "C1", "seller", "approve")
        self.assertEqual(self.writes(), [])
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()
