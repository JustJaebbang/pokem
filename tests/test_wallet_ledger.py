import sqlite3
import unittest
from services.wallet_ledger_service import get_wallet_ledger
class Cursor:
    def __init__(self,db): self.c=db.cursor()
    def __enter__(self):return self
    def __exit__(self,*args):self.c.close()
    def execute(self,q,args=()):self.c.execute(q.replace('%s','?'),args)
    def fetchall(self):return [dict(r) for r in self.c.fetchall()]
class DB:
    def __init__(self):
        self.conn=sqlite3.connect(':memory:');self.conn.row_factory=sqlite3.Row
        self.conn.create_function('CONCAT',-1,lambda *args:''.join(str(a) for a in args))
        self.conn.executescript("""
        CREATE TABLE recharge(recharge_seq INTEGER,recharge_price INTEGER,recharge_date TEXT,user_user_id TEXT);
        CREATE TABLE exchange(exchange_seq INTEGER,exchange_price INTEGER,exchange_date TEXT,user_id TEXT);
        CREATE TABLE purchase_item(purchase_item_code TEXT,user_user_id TEXT,sell_product_sell_product_code TEXT);
        CREATE TABLE cybermoney_pay(cybermoney_pay_code TEXT,cybermoney_pay_price INTEGER,cybermoney_pay_date TEXT,cybermoney_pay_status TEXT,purchase_item_purchase_item_code TEXT);
        CREATE TABLE cybermoney_pay_cancel(cybermoney_pay_cancel_code TEXT,cybermoney_pay_cancel_price INTEGER,cybermoney_pay_cancel_date TEXT,user_user_id TEXT,cybermoney_pay_cybermoney_pay_code TEXT);
        CREATE TABLE cybermoney_give(cybermoney_give_code TEXT,cybermoney_give_price INTEGER,cybermoney_give_date TEXT,cybermoney_give_status TEXT,cybermoney_pay_code TEXT);
        CREATE TABLE sell_product(sell_product_code TEXT,sell_product_title TEXT);
        CREATE TABLE post_item(sell_product_sell_product_code TEXT,user_user_id TEXT);
        CREATE TABLE post_consign_item(sell_product_sell_product_code TEXT,inspect_inspect_code TEXT);
        CREATE TABLE inspect(inspect_code TEXT,inspect_requested_no TEXT);
        CREATE TABLE inspection_request(inspection_request_no TEXT,user_user_id TEXT);
        INSERT INTO recharge VALUES(1,100000,'2026-10-31 10:00:00','buyer'),(2,999,'2026-10-31 12:00:00','other');
        INSERT INTO exchange VALUES(1,5000,'2026-10-31T11:00:00+09:00','buyer');
        INSERT INTO sell_product VALUES('P1','일반 카드'),('P2','대리판매 카드');
        INSERT INTO purchase_item VALUES('BUY1','buyer','P1'),('BUY2','buyer','P1'),('BUY3','other','P2');
        INSERT INTO cybermoney_pay VALUES('PAY1',9000,'2026-10-31T11:10:00+09:00','결제완료','BUY1'),('PAY2',8000,'2026-10-31T11:20:00+09:00','결제취소','BUY2'),('PAY3',11000,'2026-10-31T11:30:00+09:00','결제완료','BUY3');
        INSERT INTO cybermoney_pay_cancel VALUES('REF1',8000,'2026-10-31 11:40:00','buyer','PAY2');
        INSERT INTO post_item VALUES('P1','seller');
        INSERT INTO post_consign_item VALUES('P2','INS1');
        INSERT INTO inspect VALUES('INS1','REQ1');
        INSERT INTO inspection_request VALUES('REQ1','seller');
        INSERT INTO cybermoney_give VALUES('GIVE1',9000,'2026-10-31T12:00:00+09:00','지급완료','PAY1'),('GIVE2',11000,'2026-10-31T12:10:00+09:00','지급완료','PAY3'),('PENDING',1,'2026-10-31T12:20:00+09:00','지급대기','PAY1');
        """)
    def cursor(self):return Cursor(self.conn)
class WalletLedgerTests(unittest.TestCase):
    def setUp(self):self.db=DB();self.addCleanup(self.db.conn.close)
    def test_buyer_receives_signed_movements_in_chronological_order(self):
        rows=get_wallet_ledger(self.db,'buyer')
        self.assertEqual([r.kind for r in rows],['refund','payment','payment','exchange','recharge'])
        self.assertEqual([r.amount for r in rows],[8000,-8000,-9000,-5000,100000])
        self.assertTrue(all(r.user_user_id=='buyer' for r in rows))
        self.assertTrue(all(r.occurred_at.endswith('+09:00') for r in rows))
    def test_canceled_payment_remains_debit_and_actual_refund_is_separate(self):
        rows=get_wallet_ledger(self.db,'buyer')
        related=[r for r in rows if r.payment_code=='PAY2']
        self.assertEqual(len(related),2);self.assertEqual(sum(r.amount for r in related),0)
        self.db.conn.execute('DELETE FROM cybermoney_pay_cancel')
        self.assertFalse(any(r.kind=='refund' for r in get_wallet_ledger(self.db,'buyer')))
    def test_seller_gets_direct_and_consignment_credits_only_when_paid(self):
        rows=get_wallet_ledger(self.db,'seller')
        self.assertEqual([r.amount for r in rows],[11000,9000])
        self.assertTrue(all(r.kind=='sale_credit' for r in rows))
        self.assertEqual({r.product_title for r in rows},{'일반 카드','대리판매 카드'})
    def test_direction_filters_apply_before_pagination(self):
        incoming=get_wallet_ledger(self.db,'buyer',1,1,'in')
        self.assertEqual(incoming[0].kind,'recharge')
        outgoing=get_wallet_ledger(self.db,'buyer',1,1,'out')
        self.assertEqual(outgoing[0].source_code,'PAY1')
    def test_missing_product_and_empty_history(self):
        self.db.conn.execute('DELETE FROM sell_product')
        rows=get_wallet_ledger(self.db,'buyer')
        self.assertEqual(len(rows),5);self.assertIsNone(rows[0].product_title)
        self.assertEqual(get_wallet_ledger(self.db,'missing'),[])
    def test_pagination_is_stable_and_source_namespaces_do_not_collide(self):
        rows=get_wallet_ledger(self.db,'buyer')
        paged=[]
        for offset in range(5):paged.extend(get_wallet_ledger(self.db,'buyer',1,offset))
        self.assertEqual([r.event_id for r in rows],[r.event_id for r in paged])
        self.assertEqual(len({r.event_id for r in rows}),5)
