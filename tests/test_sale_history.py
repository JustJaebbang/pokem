import sqlite3
import unittest
from types import SimpleNamespace
from fastapi import FastAPI
from fastapi.testclient import TestClient
from database import get_db
from dependencies import get_current_user
from routers.sale_history import router
from services.sale_history_service import get_sale_history

class Cursor:
    def __init__(self, db): self.cursor = db.cursor()
    def __enter__(self): return self
    def __exit__(self, *args): self.cursor.close()
    def execute(self, sql, params): self.cursor.execute(sql.replace('%s', '?'), params)
    def fetchall(self): return [dict(row) for row in self.cursor.fetchall()]
class Database:
    def __init__(self):
        self.db = sqlite3.connect(':memory:', check_same_thread=False)
        self.db.row_factory = sqlite3.Row
    def cursor(self): return Cursor(self.db)

class SaleHistoryTests(unittest.TestCase):
    def setUp(self):
        self.db = Database()
        self.addCleanup(self.db.db.close)
        self.db.db.executescript('''
          CREATE TABLE post_item(post_item_code TEXT, user_user_id TEXT, sell_product_sell_product_code TEXT,
            post_item_post_date TEXT, post_item_complete_date TEXT);
          CREATE TABLE post_consign_item(post_consign_item_code TEXT, inspect_inspect_code TEXT,
            sell_product_sell_product_code TEXT, post_consign_item_date TEXT, post_consign_item_complete_date TEXT);
          CREATE TABLE inspect(inspect_code TEXT, inspect_requested_no TEXT);
          CREATE TABLE inspection_request(inspection_request_no TEXT, user_user_id TEXT);
          CREATE TABLE sell_product(sell_product_code TEXT, sell_product_title TEXT, sell_product_image TEXT,
            sell_product_sell_status TEXT, sell_product_sell_price INTEGER);
          CREATE TABLE purchase_item(purchase_item_code TEXT, sell_product_sell_product_code TEXT, purchase_item_status TEXT);
          CREATE TABLE cybermoney_pay(purchase_item_purchase_item_code TEXT, cybermoney_pay_price INTEGER);
          INSERT INTO post_item VALUES('S1', 'seller', 'P1', '2026-10-30 15:00:00', NULL);
          INSERT INTO post_item VALUES('S2', 'other', 'P2', '2026-10-30 16:00:00', NULL);
          INSERT INTO post_consign_item VALUES('C1', 'I1', 'P3', '2026-10-30T14:00:00+09:00', NULL);
          INSERT INTO post_consign_item VALUES('C2', 'I2', 'P4', '2026-10-30T17:00:00+09:00', NULL);
          INSERT INTO inspect VALUES('I1', 'IR1'), ('I2', 'IR2');
          INSERT INTO inspection_request VALUES('IR1', 'seller'), ('IR2', 'other');
          INSERT INTO sell_product VALUES('P1', '피카츄', '/media/products/card.jpg', '거래중', 99000);
          INSERT INTO sell_product VALUES('P3', '리자몽', '', '판매중', 20000);
          INSERT INTO purchase_item VALUES('PI1', 'P1', '거래중'), ('OLD', 'P1', '거래취소');
          INSERT INTO cybermoney_pay VALUES('PI1', 10000), ('OLD', 5000);
        ''')
    def test_only_owned_direct_and_consign_sales_with_actual_paid_price(self):
        rows = get_sale_history(self.db, 'seller')
        self.assertEqual([r.sale_code for r in rows], ['S1', 'C1'])
        self.assertEqual([r.sale_type for r in rows], ['direct', 'consign'])
        self.assertEqual(rows[0].paid_price, 10000)
        self.assertEqual(rows[0].asking_price, 99000)
        self.assertEqual(rows[0].image, '/media/products/card.jpg')
        self.assertTrue(rows[0].posted_at.endswith('+09:00'))
    def test_missing_product_or_payment_keeps_record(self):
        self.db.db.execute('DELETE FROM sell_product')
        self.db.db.execute('DELETE FROM cybermoney_pay')
        rows = get_sale_history(self.db, 'seller')
        self.assertEqual(len(rows), 2)
        self.assertIsNone(rows[0].title)
        self.assertIsNone(rows[0].paid_price)
    def test_duplicate_payments_do_not_duplicate_sales_or_guess_amount(self):
        self.db.db.execute("INSERT INTO cybermoney_pay VALUES('PI1', 20000)")
        rows = get_sale_history(self.db, 'seller')
        self.assertEqual(len(rows), 2)
        self.assertIsNone(rows[0].paid_price)
    def test_http_uses_authenticated_user_not_query_parameter(self):
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_db] = lambda: self.db
        app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(user_id='seller')
        with TestClient(app) as client:
            response = client.get('/sale_history?user_id=other')
        self.assertEqual(response.status_code, 200)
        self.assertEqual([r['sale_code'] for r in response.json()], ['S1', 'C1'])
    def test_empty_history(self):
        self.assertEqual(get_sale_history(self.db, 'missing'), [])
