import sqlite3
from datetime import datetime, timedelta, timezone
import unittest
from types import SimpleNamespace

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from database import get_db
from dependencies import get_current_account
from routers.return_item import router
from schemas.inspect import InspectChoice
from services import inspect_service, return_service, delivery_service, consignment_expiry_service
from tests.test_delivery_auto import install_delivery_schema


class Cursor:
    def __init__(self, db):
        self.db = db
        self.cursor = db.connection.cursor()
    def __enter__(self):
        return self
    def __exit__(self, *args):
        self.cursor.close()
    def execute(self, sql, params=()):
        if self.db.fail_on and self.db.fail_on in sql:
            raise RuntimeError("injected failure")
        sql = sql.replace("FOR UPDATE", "").replace("%s", "?")
        sql = sql.replace("ON DUPLICATE KEY UPDATE last_seq = last_seq + 1", "ON CONFLICT(delivery_date) DO UPDATE SET last_seq = last_seq + 1")
        return self.cursor.execute(sql, params)
    def fetchone(self):
        row = self.cursor.fetchone()
        if row is None:
            return None
        result = dict(row)
        if result.get('post_consign_item_expires_at') is not None:
            result['post_consign_item_expires_at'] = datetime.fromisoformat(result['post_consign_item_expires_at'])
        return result
    def fetchall(self):
        return [dict(row) for row in self.cursor.fetchall()]
    @property
    def rowcount(self):
        return self.cursor.rowcount


class Database:
    def __init__(self):
        self.connection = sqlite3.connect(":memory:", check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.fail_on = None
    def begin(self):
        self.connection.execute("BEGIN")
    def commit(self):
        self.connection.commit()
    def rollback(self):
        self.connection.rollback()
    def cursor(self):
        return Cursor(self)


class ReturnTests(unittest.TestCase):
    def setUp(self):
        self.db = Database()
        self.addCleanup(self.db.connection.close)
        self.db.connection.executescript("""
            PRAGMA foreign_keys=ON;
            CREATE TABLE user (user_id TEXT PRIMARY KEY);
            CREATE TABLE manager (manager_id TEXT PRIMARY KEY);
            CREATE TABLE inspection_request (inspection_request_no TEXT PRIMARY KEY, user_user_id TEXT REFERENCES user(user_id));
            CREATE TABLE inspect (
                inspect_code TEXT PRIMARY KEY, inspect_serial_code TEXT, seq INTEGER,
                inspect_requested_no TEXT REFERENCES inspection_request(inspection_request_no),
                inspect_status TEXT, inspect_date TEXT, inspect_grade TEXT, inspect_grade_reason TEXT,
                inspect_user_choice TEXT, inspect_user_choice_at TEXT, manager_manager_id TEXT);
            CREATE TABLE `return` (
                return_no TEXT PRIMARY KEY,
                inspect_inspect_code TEXT NOT NULL UNIQUE REFERENCES inspect(inspect_code),
                user_user_id TEXT NOT NULL REFERENCES user(user_id),
                manager_manager_id TEXT REFERENCES manager(manager_id),
                return_status TEXT NOT NULL DEFAULT '반환접수');
            INSERT INTO user VALUES ('owner'), ('other');
            INSERT INTO manager VALUES ('M'), ('M2');
            INSERT INTO inspection_request VALUES ('req', 'owner');
            INSERT INTO inspect VALUES ('INS_1', 'card', 1, 'req', '검수완료', NULL, 'A', 'good', '의사확인대기', NULL, 'M');
        """)
        install_delivery_schema(self.db.connection)
        app = FastAPI()
        app.include_router(router)
        self.app = app
        self.current = SimpleNamespace(role='user', account=SimpleNamespace(user_id='owner'))
        app.dependency_overrides[get_db] = lambda: self.db
        app.dependency_overrides[get_current_account] = lambda: self.current
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def choose(self, value='반환', user='owner'):
        return inspect_service.choose_inspect(self.db, 'INS_1', InspectChoice(inspect_user_choice=value), user)

    def created(self):
        self.choose()
        return return_service.get_returns(self.db)[0]

    def manager(self, name='M'):
        self.current = SimpleNamespace(role='manager', account=SimpleNamespace(manager_id=name))

    def test_choice_creates_one_return_and_retry_is_idempotent(self):
        self.choose()
        self.choose()
        rows = return_service.get_returns(self.db)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].user_user_id, 'owner')
        self.assertEqual(rows[0].inspect_inspect_code, 'INS_1')
        self.assertIsNone(rows[0].manager_manager_id)

    def test_return_creates_one_delivery_and_initial_history(self):
        item = self.created()
        self.choose()
        deliveries = delivery_service.get_deliveries(self.db)
        self.assertEqual(len(deliveries), 1)
        self.assertEqual(deliveries[0].return_no, item.return_no)
        self.assertEqual(deliveries[0].delivery_status, '배송준비')
        self.assertIsNone(deliveries[0].delivery_company_delivery_company_code)
        self.assertEqual(self.db.connection.execute('SELECT COUNT(*) FROM delivery_status_history').fetchone()[0], 1)

    def test_delivery_history_failure_rolls_back_return_and_choice(self):
        self.db.fail_on = 'INSERT INTO delivery_status_history'
        with self.assertRaises(RuntimeError):
            self.choose()
        self.assertEqual(self.db.connection.execute('SELECT COUNT(*) FROM `return`').fetchone()[0], 0)
        self.assertEqual(self.db.connection.execute('SELECT COUNT(*) FROM delivery').fetchone()[0], 0)
        self.assertEqual(self.db.connection.execute('SELECT inspect_user_choice FROM inspect').fetchone()[0], '의사확인대기')

    def test_return_delivery_requires_company_and_records_each_transition(self):
        item = self.created()
        delivery = delivery_service.get_deliveries(self.db)[0]
        self.db.rollback()
        with self.assertRaises(HTTPException):
            delivery_service.update_delivery_status(self.db, delivery.delivery_no, '배송중', 'M')
        assigned = delivery_service.assign_delivery_company(self.db, delivery.delivery_no, 'CO', 'M')
        self.assertEqual(assigned.delivery_company_delivery_company_code, 'CO')
        with self.assertRaises(HTTPException):
            delivery_service.update_delivery_status(self.db, delivery.delivery_no, '배송완료', 'M')
        delivery_service.update_delivery_status(self.db, delivery.delivery_no, '배송중', 'M')
        delivery_service.update_delivery_status(self.db, delivery.delivery_no, '배송중', 'M')
        delivery_service.update_delivery_status(self.db, delivery.delivery_no, '배송완료', 'M')
        self.assertEqual(return_service.get_return(self.db, item.return_no).return_status, '반환완료')
        histories = delivery_service.get_delivery_status_history(self.db, delivery.delivery_no)
        self.assertEqual([h.changed_status for h in histories], ['배송준비', '배송중', '배송완료'])

    def test_company_assignment_rejects_missing_company_and_late_changes(self):
        self.created()
        delivery = delivery_service.get_deliveries(self.db)[0]
        self.db.rollback()
        with self.assertRaises(HTTPException) as error:
            delivery_service.assign_delivery_company(self.db, delivery.delivery_no, 'missing', 'M')
        self.assertEqual(error.exception.status_code, 404)
        delivery_service.assign_delivery_company(self.db, delivery.delivery_no, 'CO', 'M')
        delivery_service.update_delivery_status(self.db, delivery.delivery_no, '배송중', 'M')
        with self.assertRaises(HTTPException) as error:
            delivery_service.assign_delivery_company(self.db, delivery.delivery_no, 'CO', 'M')
        self.assertEqual(error.exception.status_code, 409)

    def test_cancelled_purchase_cannot_start_delivery(self):
        self.db.connection.execute("INSERT INTO purchase_item VALUES ('BUY', 'owner', 'P', '거래취소')")
        with self.db.cursor() as c:
            delivery = delivery_service.ensure_automatic_delivery(c, manager_id='M', user_id='owner', purchase_code='BUY', product_code='P')
        self.db.commit()
        delivery_service.assign_delivery_company(self.db, delivery.delivery_no, 'CO', 'M')
        with self.assertRaises(HTTPException) as error:
            delivery_service.update_delivery_status(self.db, delivery.delivery_no, '배송중', 'M')
        self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(self.db.connection.execute('SELECT COUNT(*) FROM delivery_status_history').fetchone()[0], 1)

    def test_expired_consignment_reuses_automatic_return_delivery(self):
        self.choose('대리판매')
        self.db.connection.executescript("""
            CREATE TABLE sell_product(sell_product_code TEXT PRIMARY KEY, sell_product_sell_status TEXT);
            CREATE TABLE post_consign_item(post_consign_item_code TEXT PRIMARY KEY,
                sell_product_sell_product_code TEXT, post_consign_item_complete_date TEXT,
                post_consign_item_intention TEXT, post_consign_item_expires_at TEXT,
                inspect_inspect_code TEXT, manager_manager_id TEXT, return_delivery_company_code TEXT);
            INSERT INTO sell_product VALUES ('P', '판매중');
            INSERT INTO post_consign_item VALUES ('CON', 'P', NULL, '대리판매', '2026-01-01T00:00:00', 'INS_1', 'M', 'CO');
        """)
        now = datetime(2026, 11, 2, tzinfo=timezone(timedelta(hours=9)))
        result = consignment_expiry_service.expire_consignment(self.db, 'CON', now=now)
        self.assertEqual(result.delivery_status, '배송준비')
        self.assertIsNone(result.delivery_company_delivery_company_code)
        self.assertIsNone(consignment_expiry_service.expire_consignment(self.db, 'CON', now=now))
        self.assertEqual(self.db.connection.execute('SELECT COUNT(*) FROM delivery').fetchone()[0], 1)
        self.assertEqual(self.db.connection.execute('SELECT COUNT(*) FROM delivery_status_history').fetchone()[0], 1)

    def test_consign_does_not_create_return(self):
        self.choose('대리판매')
        self.assertEqual(return_service.get_returns(self.db), [])

    def test_creation_failure_rolls_back_user_choice(self):
        self.db.fail_on = 'INSERT INTO `return`'
        with self.assertRaises(RuntimeError):
            self.choose()
        row = self.db.connection.execute('SELECT inspect_user_choice, inspect_user_choice_at FROM inspect').fetchone()
        self.assertEqual(row[0], '의사확인대기')
        self.assertIsNone(row[1])
        self.assertEqual(self.db.connection.execute('SELECT COUNT(*) FROM `return`').fetchone()[0], 0)

    def test_only_owner_after_completion_can_choose(self):
        with self.assertRaises(HTTPException) as error:
            self.choose(user='other')
        self.assertEqual(error.exception.status_code, 403)
        self.db.connection.execute("UPDATE inspect SET inspect_status='검수중'")
        self.db.connection.commit()
        with self.assertRaises(HTTPException) as error:
            self.choose()
        self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(return_service.get_returns(self.db), [])

    def test_user_visibility_and_role_permissions(self):
        item = self.created()
        self.assertEqual(len(self.client.get('/return').json()), 1)
        self.assertEqual(self.client.patch(f'/return/{item.return_no}/manager', json={}).status_code, 403)
        self.current = SimpleNamespace(role='user', account=SimpleNamespace(user_id='other'))
        self.assertEqual(self.client.get('/return').json(), [])
        self.assertEqual(self.client.get(f'/return/{item.return_no}').status_code, 404)
        self.manager()
        self.assertEqual(len(self.client.get('/return').json()), 1)

    def test_assignment_permissions_and_duplicate_rejection(self):
        item = self.created()
        path = f'/return/{item.return_no}'
        self.manager()
        self.assertEqual(self.client.patch(path+'/manager', json={'manager_manager_id':'M2'}).status_code, 403)
        response = self.client.patch(path+'/manager', json={})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['manager_manager_id'], 'M')
        self.assertEqual(set(response.json()), {
            'return_no', 'inspect_inspect_code', 'user_user_id', 'manager_manager_id', 'return_status',
        })
        self.assertEqual(self.client.patch(path+'/manager', json={}).status_code, 409)
        self.manager('M2')
        self.assertEqual(self.client.patch(path+'/manager', json={}).status_code, 409)
        self.assertEqual(return_service.get_return(self.db, item.return_no).manager_manager_id, 'M')

    def test_assignment_write_failure_rolls_back(self):
        item = self.created()
        self.db.fail_on = 'UPDATE `return`'
        with self.assertRaises(RuntimeError):
            return_service.assign_manager(self.db, item.return_no, 'M')
        self.db.fail_on = None
        self.assertIsNone(return_service.get_return(self.db, item.return_no).manager_manager_id)

    def test_assignment_missing_manager_and_return(self):
        item = self.created()
        with self.assertRaises(HTTPException):
            return_service.assign_manager(self.db, item.return_no, 'missing')
        self.assertIsNone(return_service.get_return(self.db, item.return_no).manager_manager_id)
        self.manager()
        self.assertEqual(self.client.get('/return/missing').status_code, 404)
        self.assertEqual(self.client.patch('/return/missing/manager', json={}).status_code, 404)

    def test_complete_endpoint_is_removed(self):
        self.manager()
        self.assertEqual(self.client.post('/return/missing/complete').status_code, 404)
        self.assertNotIn('/return/{return_no}/complete', self.app.openapi()['paths'])

    def test_list_orders_by_choice_time_before_pagination(self):
        self.created()
        self.db.connection.execute("UPDATE inspect SET inspect_user_choice_at='2026-10-29T10:00:00+09:00'")
        self.db.connection.execute("""INSERT INTO inspect VALUES (
            'INS_2', 'card', 2, 'req', '검수완료', NULL, 'A', 'good',
            '반환', '2026-10-30T10:00:00+09:00', 'M')""")
        self.db.connection.execute("INSERT INTO `return` VALUES ('AAA', 'INS_2', 'owner', NULL, '반환접수')")
        self.db.connection.commit()
        latest = return_service.get_returns(self.db, user_id='owner', limit=1)
        self.assertEqual(latest[0].return_no, 'AAA')
        older = return_service.get_returns(self.db, user_id='owner', limit=1, offset=1)
        self.assertEqual(older[0].inspect_inspect_code, 'INS_1')

    def test_inspect_filter_preserves_owner_scope(self):
        self.created()
        response = self.client.get('/return?inspect_code=INS_1')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.json()), 1)
        self.assertEqual(self.client.get('/return?inspect_code=missing').json(), [])
        self.current = SimpleNamespace(role='user', account=SimpleNamespace(user_id='other'))
        self.assertEqual(self.client.get('/return?inspect_code=INS_1').json(), [])

    def test_authentication_required(self):
        self.app.dependency_overrides.pop(get_current_account)
        self.assertEqual(self.client.get('/return').status_code, 401)
        self.assertEqual(self.client.get('/return/missing').status_code, 401)
        self.assertEqual(self.client.patch('/return/missing/manager', json={}).status_code, 401)


if __name__ == '__main__':
    unittest.main()
