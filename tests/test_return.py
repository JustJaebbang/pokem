import sqlite3
import unittest
from types import SimpleNamespace

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from database import get_db
from dependencies import get_current_account
from routers.return_item import router
from schemas.inspect import InspectChoice
from services import inspect_service, return_service


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
        return self.cursor.execute(sql.replace("FOR UPDATE", "").replace("%s", "?"), params)
    def fetchone(self):
        row = self.cursor.fetchone()
        return dict(row) if row is not None else None
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
                manager_manager_id TEXT REFERENCES manager(manager_id));
            INSERT INTO user VALUES ('owner'), ('other');
            INSERT INTO manager VALUES ('M'), ('M2');
            INSERT INTO inspection_request VALUES ('req', 'owner');
            INSERT INTO inspect VALUES ('INS_1', 'card', 1, 'req', '검수완료', NULL, 'A', 'good', '의사확인대기', NULL, 'M');
        """)
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
            'return_no', 'inspect_inspect_code', 'user_user_id', 'manager_manager_id',
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
        self.db.connection.execute("INSERT INTO `return` VALUES ('AAA', 'INS_2', 'owner', NULL)")
        self.db.connection.commit()
        latest = return_service.get_returns(self.db, user_id='owner', limit=1)
        self.assertEqual(latest[0].return_no, 'AAA')
        older = return_service.get_returns(self.db, user_id='owner', limit=1, offset=1)
        self.assertEqual(older[0].inspect_inspect_code, 'INS_1')

    def test_authentication_required(self):
        self.app.dependency_overrides.pop(get_current_account)
        self.assertEqual(self.client.get('/return').status_code, 401)
        self.assertEqual(self.client.get('/return/missing').status_code, 401)
        self.assertEqual(self.client.patch('/return/missing/manager', json={}).status_code, 401)


if __name__ == '__main__':
    unittest.main()
