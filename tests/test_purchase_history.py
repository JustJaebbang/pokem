import sqlite3
import unittest
from schemas.purchase_item import PurchaseItemDetailResponse
from services.purchase_item_service import get_purchase_item, get_purchase_item_code

class Cursor:
    def __init__(self, connection): self.cursor = connection.cursor()
    def __enter__(self): return self
    def __exit__(self, *args): self.cursor.close()
    def execute(self, sql, params): self.cursor.execute(sql.replace('%s', '?'), params)
    def fetchone(self):
        row = self.cursor.fetchone()
        return dict(row) if row is not None else None
    def fetchall(self): return [dict(row) for row in self.cursor.fetchall()]

class Database:
    def __init__(self):
        self.connection = sqlite3.connect(':memory:')
        self.connection.row_factory = sqlite3.Row
    def cursor(self): return Cursor(self.connection)

class PurchaseHistoryTests(unittest.TestCase):
    def setUp(self):
        self.db = Database()
        self.addCleanup(self.db.connection.close)
        self.db.connection.executescript('''
            CREATE TABLE user (user_id TEXT);
            CREATE TABLE purchase_item (purchase_item_code TEXT, user_user_id TEXT,
                purchase_item_date TEXT, purchase_item_status TEXT,
                sell_product_sell_product_code TEXT);
            CREATE TABLE sell_product (sell_product_code TEXT, sell_product_title TEXT,
                sell_product_image TEXT, sell_product_sell_price INTEGER);
            CREATE TABLE cybermoney_pay (purchase_item_purchase_item_code TEXT,
                cybermoney_pay_price INTEGER, cybermoney_pay_status TEXT);
            INSERT INTO user VALUES ('buyer');
            INSERT INTO sell_product VALUES ('P1', '피카츄', '/media/products/card.jpg', 99000);
            INSERT INTO purchase_item VALUES ('PI1', 'buyer', '2026-10-30T16:00:00+09:00', '거래중', 'P1');
            INSERT INTO purchase_item VALUES ('PI2', 'other', '2026-10-30', '거래중', 'P1');
            INSERT INTO cybermoney_pay VALUES ('PI1', 10000, '결제완료');
        ''')
    def test_history_joins_product_and_original_payment_and_filters_buyer(self):
        items = get_purchase_item(self.db, 'buyer')
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0].sell_product_title, '피카츄')
        self.assertEqual(items[0].sell_product_image, '/media/products/card.jpg')
        self.assertEqual(items[0].cybermoney_pay_price, 10000)
        self.assertEqual(items[0].purchase_item_date, '2026-10-30T16:00:00+09:00')
        single = get_purchase_item_code(self.db, 'PI1')
        self.assertEqual(single, items[0])
        self.assertEqual(PurchaseItemDetailResponse.model_validate(single.model_dump()).cybermoney_pay_price, 10000)
    def test_missing_product_or_payment_preserves_history_without_guessing_price(self):
        self.db.connection.execute('DELETE FROM sell_product')
        self.db.connection.execute('DELETE FROM cybermoney_pay')
        item = get_purchase_item(self.db, 'buyer')[0]
        self.assertIsNone(item.sell_product_title)
        self.assertIsNone(item.sell_product_image)
        self.assertIsNone(item.cybermoney_pay_price)
    def test_duplicate_payment_does_not_duplicate_history_or_guess_amount(self):
        self.db.connection.execute("INSERT INTO cybermoney_pay VALUES ('PI1', 20000, '결제완료')")
        items = get_purchase_item(self.db, 'buyer')
        self.assertEqual(len(items), 1)
        self.assertIsNone(items[0].cybermoney_pay_price)
    def test_cancelled_payment_retains_original_amount(self):
        self.db.connection.execute("UPDATE cybermoney_pay SET cybermoney_pay_status='결제취소'")
        self.assertEqual(get_purchase_item(self.db, 'buyer')[0].cybermoney_pay_price, 10000)
