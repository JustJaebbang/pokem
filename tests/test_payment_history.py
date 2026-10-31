import sqlite3
import unittest
from services.cybermoney_pay_service import get_cybermoney_pay, get_cybermoney_pay_code
from schemas.cybermoney_pay import CybermoneyPayResponse
class Cursor:
    def __init__(self,conn): self.c=conn.cursor()
    def __enter__(self): return self
    def __exit__(self,*args): self.c.close()
    def execute(self,q,args=()): self.c.execute(q.replace("%s","?"),args)
    def fetchone(self):
        row=self.c.fetchone()
        return dict(row) if row else None
    def fetchall(self): return [dict(row) for row in self.c.fetchall()]
class DB:
    def __init__(self):
        self.conn=sqlite3.connect(":memory:")
        self.conn.row_factory=sqlite3.Row
        self.conn.executescript("""
          CREATE TABLE user(user_id TEXT);
          CREATE TABLE sell_product(sell_product_code TEXT,sell_product_title TEXT,sell_product_image TEXT);
          CREATE TABLE purchase_item(purchase_item_code TEXT,user_user_id TEXT,sell_product_sell_product_code TEXT);
          CREATE TABLE cybermoney_pay(cybermoney_pay_code TEXT,cybermoney_pay_status TEXT,cybermoney_pay_date TEXT,cybermoney_pay_price INTEGER,purchase_item_purchase_item_code TEXT);
          INSERT INTO user VALUES('buyer'),('other');
          INSERT INTO sell_product VALUES('P1','카드 상품','/media/products/card.jpg');
          INSERT INTO purchase_item VALUES('BUY1','buyer','P1'),('BUY2','buyer','P1'),('BUY3','other','P1');
          INSERT INTO cybermoney_pay VALUES('PAY1','결제완료','2026-10-30T10:00:00+09:00',9000,'BUY1'),('PAY2','결제취소','2026-10-31T10:00:00+09:00',8000,'BUY2'),('PAY3','결제완료','2026-10-31T10:00:00+09:00',7000,'BUY3');
        """)
    def cursor(self): return Cursor(self.conn)
class PaymentHistoryTests(unittest.TestCase):
    def setUp(self):
        self.db=DB();self.addCleanup(self.db.conn.close)
    def test_history_filters_buyer_and_joins_product_without_duplicate_rows(self):
        rows=get_cybermoney_pay(self.db,'buyer')
        self.assertEqual([r.cybermoney_pay_code for r in rows],['PAY2','PAY1'])
        self.assertTrue(all(r.sell_product_title=='카드 상품' for r in rows))
        self.assertEqual(rows[0].sell_product_image,'/media/products/card.jpg')
    def test_canceled_payment_keeps_original_amount_status_and_time(self):
        row=get_cybermoney_pay_code(self.db,'PAY2')
        self.assertEqual(row.cybermoney_pay_price,8000)
        self.assertEqual(row.cybermoney_pay_status,'결제취소')
        self.assertEqual(row.cybermoney_pay_date,'2026-10-31T10:00:00+09:00')
    def test_missing_product_does_not_hide_payment(self):
        self.db.conn.execute('DELETE FROM sell_product')
        rows=get_cybermoney_pay(self.db,'buyer')
        self.assertEqual(len(rows),2)
        self.assertIsNone(rows[0].sell_product_title)
        self.assertEqual(rows[0].sell_product_sell_product_code,'P1')
    def test_detail_matches_list_and_missing_payment_returns_none(self):
        self.assertEqual(get_cybermoney_pay_code(self.db,'PAY2'),get_cybermoney_pay(self.db,'buyer')[0])
        self.assertIsNone(get_cybermoney_pay_code(self.db,'MISSING'))
    def test_old_response_remains_valid_without_product_fields(self):
        data=dict(cybermoney_pay_code='PAY1',cybermoney_pay_status='결제완료',cybermoney_pay_date='date',cybermoney_pay_price=100,purchase_item_purchase_item_code='BUY1',user_user_id='buyer')
        self.assertIsNone(CybermoneyPayResponse(**data).sell_product_title)
