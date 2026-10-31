import sqlite3
import unittest
from services.pending_actions_service import get_pending_actions
class Cursor:
    def __init__(self,db):self.c=db.cursor()
    def __enter__(self):return self
    def __exit__(self,*args):self.c.close()
    def execute(self,q,args):self.c.execute(q.replace('%s','?'),args)
    def fetchone(self):return dict(self.c.fetchone())
class DB:
    def __init__(self):
        self.conn=sqlite3.connect(':memory:');self.conn.row_factory=sqlite3.Row
        self.conn.executescript("""
        CREATE TABLE pay(inspection_request_inspection_request_no TEXT,user_user_id TEXT,pay_status TEXT,pay_price INTEGER);
        CREATE TABLE inspection_request(inspection_request_no TEXT,user_user_id TEXT);
        CREATE TABLE inspect(inspect_code TEXT,inspect_requested_no TEXT,inspect_status TEXT,inspect_user_choice TEXT);
        CREATE TABLE post_item(sell_product_sell_product_code TEXT,user_user_id TEXT);
        CREATE TABLE post_consign_item(sell_product_sell_product_code TEXT,inspect_inspect_code TEXT);
        CREATE TABLE purchase_item(purchase_item_code TEXT,purchase_item_status TEXT,sell_product_sell_product_code TEXT);
        CREATE TABLE purchase_cancel(purchase_item_purchase_item_code TEXT,purchase_cancel_status TEXT);
        INSERT INTO inspection_request VALUES('R1','me'),('R2','me'),('R3','other');
        INSERT INTO pay VALUES('R1','me','결제대기',0),('R2','me','결제완료',10000),('R3','other','결제대기',10000),('BAD','me','결제대기',NULL);
        INSERT INTO inspect VALUES('I1','R1','검수완료','의사확인대기'),('I2','R1','검수중','의사확인대기'),('I3','R2','검수완료','반환'),('I4','R3','검수완료','의사확인대기'),('I5','R2','검수완료','의사확인대기'),('I6','R2','검수완료','대리판매');
        INSERT INTO post_item VALUES('P1','me'),('P2','other');
        INSERT INTO post_consign_item VALUES('P3','I6');
        INSERT INTO purchase_item VALUES('B1','취소요청','P1'),('B2','취소요청','P2'),('B3','취소요청','P3'),('B4','거래중','P1');
        INSERT INTO purchase_cancel VALUES('B1','요청중'),('B2','요청중'),('B3','요청중'),('B4','거절');
        """)
    def cursor(self):return Cursor(self.conn)
class PendingActionsTests(unittest.TestCase):
    def setUp(self):self.db=DB();self.addCleanup(self.db.conn.close)
    def test_counts_only_actionable_own_records_and_returns_request_targets(self):
        result=get_pending_actions(self.db,'me')
        self.assertEqual(result.fee_count,1);self.assertEqual(result.fee_request_no,'R1')
        self.assertEqual(result.choice_count,2);self.assertEqual(result.choice_request_no,'R1')
        self.assertEqual(result.cancel_count,2)
    def test_empty_account_has_zero_counts_and_no_targets(self):
        result=get_pending_actions(self.db,'empty')
        self.assertEqual((result.fee_count,result.choice_count,result.cancel_count),(0,0,0))
        self.assertIsNone(result.fee_request_no);self.assertIsNone(result.choice_request_no)
    def test_cancel_ownership_includes_consignments_without_duplicate_counts(self):
        self.db.conn.execute("INSERT INTO post_item VALUES('P3','me')")
        self.assertEqual(get_pending_actions(self.db,'me').cancel_count,2)
        self.assertEqual(get_pending_actions(self.db,'other').cancel_count,1)
    def test_completed_work_disappears_on_next_read(self):
        self.db.conn.execute("UPDATE pay SET pay_status='결제완료' WHERE user_user_id='me'")
        self.db.conn.execute("UPDATE inspect SET inspect_user_choice='반환' WHERE inspect_requested_no IN ('R1','R2')")
        self.db.conn.execute("UPDATE purchase_cancel SET purchase_cancel_status='승인'")
        result=get_pending_actions(self.db,'me')
        self.assertEqual((result.fee_count,result.choice_count,result.cancel_count),(0,0,0))
    def test_cancellation_must_still_be_requested_on_both_records(self):
        self.db.conn.execute("UPDATE purchase_item SET purchase_item_status='거래중' WHERE purchase_item_code='B1'")
        self.assertEqual(get_pending_actions(self.db,'me').cancel_count,1)
