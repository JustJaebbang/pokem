import sqlite3
import unittest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from database import get_db
from routers.review import router
from services.review_service import get_review

class Cursor:
    def __init__(self,connection):self.cursor=connection.cursor()
    def __enter__(self):return self
    def __exit__(self,*args):self.cursor.close()
    def execute(self,sql,params=()):self.cursor.execute(sql.replace('%s','?'),params)
    def fetchall(self):return [dict(row) for row in self.cursor.fetchall()]
class Database:
    def __init__(self):
        self.connection=sqlite3.connect(':memory:',check_same_thread=False)
        self.connection.row_factory=sqlite3.Row
    def cursor(self):return Cursor(self.connection)
class SellerReviewTests(unittest.TestCase):
    def setUp(self):
        self.db=Database();self.addCleanup(self.db.connection.close)
        self.db.connection.executescript('''
            CREATE TABLE review(review_code TEXT,purchase_item_purchase_item_code TEXT,review_contents TEXT,
              review_rating INTEGER,review_date TEXT,user_user_id TEXT,sell_product_sell_product_code TEXT);
            CREATE TABLE post_item(sell_product_sell_product_code TEXT,user_user_id TEXT);
            CREATE TABLE post_consign_item(sell_product_sell_product_code TEXT,inspect_inspect_code TEXT);
            CREATE TABLE inspect(inspect_code TEXT,inspect_requested_no TEXT);
            CREATE TABLE inspection_request(inspection_request_no TEXT,user_user_id TEXT);
            INSERT INTO post_item VALUES('P1','sellerA'),('P3','sellerB');
            INSERT INTO post_consign_item VALUES('P2','I2');
            INSERT INTO inspect VALUES('I2','IR2');
            INSERT INTO inspection_request VALUES('IR2','sellerA');
            INSERT INTO review VALUES('R1','PI1','direct',5,'2026-10-30','buyer','P1');
            INSERT INTO review VALUES('R2','PI2','consign',3,'2026-10-31','buyer2','P2');
            INSERT INTO review VALUES('R3','PI3','buyer is sellerA',1,'2026-10-31T12:00:00','sellerA','P3');
        ''')
    def test_collects_direct_and_consign_sales_not_reviews_written_by_seller(self):
        rows=get_review(self.db,seller_user_id='sellerA')
        self.assertEqual([row.review_code for row in rows],['R2','R1'])
        self.assertEqual([row.review_rating for row in rows],[3,5])
        self.assertEqual([row.review_code for row in get_review(self.db,seller_user_id='sellerB')],['R3'])
    def test_combined_product_seller_filters_and_empty_seller(self):
        self.assertEqual([r.review_code for r in get_review(self.db,'P2',seller_user_id='sellerA')],['R2'])
        self.assertEqual(get_review(self.db,'P3',seller_user_id='sellerA'),[])
        self.assertEqual(get_review(self.db,seller_user_id='missing'),[])
    def test_duplicate_registration_does_not_duplicate_review(self):
        self.db.connection.execute("INSERT INTO post_item VALUES('P1','sellerA')")
        self.assertEqual(len(get_review(self.db,seller_user_id='sellerA')),2)
    def test_original_product_and_all_review_queries_remain_available(self):
        self.assertEqual(len(get_review(self.db)),3)
        self.assertEqual([r.review_code for r in get_review(self.db,'P1')],['R1'])
    def test_public_http_seller_filter_and_invalid_empty_id(self):
        app=FastAPI();app.include_router(router);app.dependency_overrides[get_db]=lambda:self.db
        with TestClient(app) as client:
            response=client.get('/review?seller_user_id=sellerA')
            self.assertEqual(response.status_code,200)
            self.assertEqual([r['review_code'] for r in response.json()],['R2','R1'])
            self.assertEqual(client.get('/review?seller_user_id=').status_code,422)
            self.assertEqual(client.get('/review?seller_user_id='+('a'*21)).status_code,422)
