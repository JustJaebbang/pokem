import unittest
from test_wallet_ledger import DB
from services.notification_service import get_notifications
class NotificationsTests(unittest.TestCase):
    def setUp(self):
        self.db=DB();self.addCleanup(self.db.conn.close)
        self.db.conn.executescript("""
        CREATE TABLE pay(pay_no TEXT,pay_date TEXT,pay_status TEXT,pay_price INTEGER,user_user_id TEXT,inspection_request_inspection_request_no TEXT);
        ALTER TABLE inspect ADD COLUMN inspect_status TEXT;
        ALTER TABLE inspect ADD COLUMN inspect_date TEXT;
        ALTER TABLE inspect ADD COLUMN inspect_grade_reason TEXT;
        ALTER TABLE purchase_item ADD COLUMN purchase_item_status TEXT;
        CREATE TABLE purchase_cancel(purchase_cancel_code TEXT,purchase_cancel_status TEXT,purchase_cancel_date TEXT,responded_at TEXT,user_user_id TEXT,purchase_item_purchase_item_code TEXT);
        INSERT INTO pay VALUES('FEE1','2026-10-31 15:00:00','결제대기',10000,'buyer','RQ1'),('FEE2','2026-10-31 15:00:00','결제대기',10000,'other','RQ2');
        INSERT INTO inspection_request VALUES('RQ1','buyer');
        INSERT INTO inspect VALUES('RESULT','RQ1','검수완료','2026-10-31T14:00:00+09:00','INTERNAL_SECRET_REASON');
        INSERT INTO purchase_item VALUES('BUY4','other','P1','취소요청');
        INSERT INTO purchase_cancel VALUES('PENDING','요청중','2026-10-31 16:00:00',NULL,'other','BUY4'),('DECIDED','승인','2026-10-31 11:30:00','2026-10-31 11:40:00','buyer','BUY2');
        """)
    def test_buyer_feed_includes_own_fee_inspection_response_and_actual_refund(self):
        items=get_notifications(self.db,'buyer')
        self.assertEqual(len(items),4)
        self.assertEqual({i.target_type for i in items},{'inspection_fee','inspection_result','purchase_cancel','wallet'})
        self.assertTrue(all(i.user_user_id=='buyer' for i in items))
        self.assertEqual(items[0].id,'fee:FEE1')
    def test_seller_gets_own_pending_cancel_and_direct_and_consign_payouts(self):
        items=get_notifications(self.db,'seller')
        self.assertEqual(len(items),3)
        self.assertEqual(sum(i.target_type=='wallet' for i in items),2)
        self.assertEqual(sum(i.target_type=='seller_cancel' for i in items),1)
    def test_private_grade_reason_is_not_selected_or_exposed(self):
        self.assertNotIn('INTERNAL_SECRET_REASON',str([i.model_dump() for i in get_notifications(self.db,'buyer')]))
    def test_completed_fee_and_processed_seller_request_leave_pending_feed(self):
        self.db.conn.execute("UPDATE pay SET pay_status='결제완료'")
        self.db.conn.execute("UPDATE purchase_cancel SET purchase_cancel_status='거절' WHERE purchase_cancel_code='PENDING'")
        self.assertFalse(any(i.target_type=='inspection_fee' for i in get_notifications(self.db,'buyer')))
        self.assertFalse(any(i.target_type=='seller_cancel' for i in get_notifications(self.db,'seller')))
    def test_stable_ids_and_no_cross_account_items(self):
        first=get_notifications(self.db,'buyer');second=get_notifications(self.db,'buyer')
        self.assertEqual([i.id for i in first],[i.id for i in second])
        self.assertEqual(len({i.id for i in first}),len(first))
        self.assertEqual(get_notifications(self.db,'missing'),[])
