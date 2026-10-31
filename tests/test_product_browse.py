import sqlite3
import unittest
from fastapi.testclient import TestClient
from database import get_db
from main import app
from services.sell_product_service import get_sell_product
class Cursor:
    def __init__(self,db):self.c=db.cursor()
    def __enter__(self):return self
    def __exit__(self,*args):self.c.close()
    def execute(self,q,args=()):self.c.execute(q.replace('%s','?'),args)
    def fetchall(self):return [dict(r) for r in self.c.fetchall()]
class DB:
    def __init__(self):
        self.conn=sqlite3.connect(':memory:',check_same_thread=False);self.conn.row_factory=sqlite3.Row
        self.conn.executescript("""
        CREATE TABLE cardinfo(cardinfo_serial_code TEXT, cardinfo_category TEXT, cardinfo_brand TEXT);
        INSERT INTO cardinfo VALUES('SV_A_1','포켓몬','A'),('SV-A2','포켓몬','B'),('SV_B_4','유희왕','A'),('SV_B_3','포켓몬','A');
        CREATE TABLE sell_product(sell_product_code TEXT PRIMARY KEY,sell_product_serial_code TEXT,seq INTEGER,sell_product_title TEXT,sell_product_image TEXT,sell_product_contents TEXT,sell_product_sell_price INTEGER,sell_product_grade TEXT,sell_product_sell_status TEXT);
        CREATE TABLE post_item(sell_product_sell_product_code TEXT,post_item_post_date TEXT);
        CREATE TABLE post_consign_item(sell_product_sell_product_code TEXT,post_consign_item_date TEXT);
        INSERT INTO sell_product VALUES('P1','SV_A_1',1,'피카츄 100% 카드','','깨끗한 카드',10000,'Unrank','판매중'),('P2','SV-A2',2,'리자몽','','설명',5000,'Unrank','판매중'),('P3','SV_B_3',3,'피카츄','','설명',20000,'Unrank','거래완료'),('P4','SV_B_4',4,'특가!','','설명',5000,'Unrank','판매중'),('P5','SV_B_5',5,'피카츄','','설명',4000,'Unrank','거래중');
        INSERT INTO post_item VALUES('P1','2026-10-30 10:00:00'),('P2','2026-10-31T10:00:00+09:00'),('P3','2026-10-31T11:00:00+09:00'),('P4','2026-10-30 12:00:00'),('P5','2026-10-31 13:00:00');
        INSERT INTO post_consign_item VALUES('P4','2026-10-31T12:00:00+09:00');
        """)
    def cursor(self):return Cursor(self.conn)
class ProductBrowseTests(unittest.TestCase):
    def setUp(self):self.db=DB();self.addCleanup(self.db.conn.close)
    def codes(self,**params):return [r.sell_product_code for r in get_sell_product(self.db,**params)]
    def test_legacy_list_keeps_all_statuses(self):self.assertEqual(len(self.codes()),5)
    def test_latest_and_price_sort_share_stable_tie_breaking(self):
        self.assertEqual(self.codes(status='판매중',sort='newest'),['P4','P2','P1'])
        self.assertEqual(self.codes(status='판매중',sort='price_asc'),['P4','P2','P1'])
        self.assertEqual(self.codes(status='판매중',sort='price_desc'),['P1','P4','P2'])
    def test_filter_before_pagination_and_no_duplicate_registration_rows(self):
        self.assertEqual(self.codes(status='판매중',sort='newest',limit=1,offset=1),['P2'])
        self.assertEqual(len(self.codes(status='판매중',sort='newest')),3)
    def test_keyword_and_literal_wildcards_are_parameterized(self):
        for query,expected in [('피카츄',['P1']),('100%',['P1']),('SV_A_',['P1']),('특가!',['P4']),('깨끗한',['P1']), ("' OR 1=1 --",[])]:
            with self.subTest(query=query):self.assertEqual(self.codes(status='판매중',q=query),expected)
        self.assertEqual(len(self.codes()),5)
    def test_code_filter_keeps_trading_and_completed_wishlist_items(self):
        self.assertEqual(set(self.codes(codes=['P3','P5'])),{'P3','P5'})
        self.assertEqual(self.codes(codes=[]),[])
    def test_classification_filters_before_paging(self):
        self.assertEqual(self.codes(status='판매중', category='포켓몬', sort='price_asc', limit=1), ['P2'])
        self.assertEqual(self.codes(status='판매중', category='포켓몬', brand='A'), ['P1'])
        self.assertEqual(self.codes(status='판매중', brand='A'), ['P4','P1'])
        self.assertEqual(self.codes(category="' OR 1=1 --"), [])
        self.assertEqual(self.codes(category='없는 분류'), [])

    def test_public_api_validation_and_query_contract(self):
        previous=dict(app.dependency_overrides)
        self.addCleanup(lambda:(app.dependency_overrides.clear(),app.dependency_overrides.update(previous)))
        app.dependency_overrides[get_db]=lambda:self.db
        client=TestClient(app);self.addCleanup(client.close)
        result=client.get('/sell_product',params={'q':'피카츄','status':'판매중','limit':20,'sort':'newest'})
        self.assertEqual(result.status_code,200,result.text);self.assertEqual(result.json()[0]['sell_product_code'],'P1')
        filters=client.get('/sell_product/filters')
        self.assertEqual(filters.status_code,200)
        self.assertEqual(len(filters.json()),3)
        for params in [{'category':'x'*31},{'brand':'x'*51},{'q':'x'*201},{'sort':'DROP TABLE'},{'limit':0},{'limit':101},{'offset':-1},{'offset':1}]:
            with self.subTest(params=params):self.assertEqual(client.get('/sell_product',params=params).status_code,422)
