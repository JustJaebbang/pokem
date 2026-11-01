import os
import re
import sqlite3
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch
from fastapi import FastAPI
from fastapi.testclient import TestClient
from database import get_db
from dependencies import get_current_user
from routers.push import router
from services import push_service as service
from services.push_worker import process_one

A='a'*32
B='b'*32
TOKEN='sample-registration-fid-1'
class Cursor:
    def __init__(self,conn):self.c=conn.cursor()
    def __enter__(self):return self
    def __exit__(self,*args):self.c.close()
    def execute(self,sql,args=()):
        sql=sql.replace(' FOR UPDATE SKIP LOCKED','').replace(' FOR UPDATE','')
        sql=sql.replace('UTC_TIMESTAMP(6)-INTERVAL 7 DAY',"datetime('now','-7 days')")
        sql=sql.replace('UTC_TIMESTAMP(6)+INTERVAL 60 SECOND',"datetime('now','+60 seconds')")
        sql=sql.replace('UTC_TIMESTAMP(6)+INTERVAL %s SECOND',"datetime('now','+' || %s || ' seconds')")
        sql=sql.replace('UTC_TIMESTAMP(6)',"datetime('now')")
        if 'ON DUPLICATE KEY UPDATE event_key' in sql:
            sql=sql.split('ON DUPLICATE KEY')[0]+' ON CONFLICT(event_key,installation_id) DO NOTHING'
        elif 'ON DUPLICATE KEY UPDATE' in sql:
            sql=sql.replace('ON DUPLICATE KEY UPDATE','ON CONFLICT(installation_id) DO UPDATE SET')
            sql=re.sub(r'VALUES\((\w+)\)',r'excluded.\1',sql)
        self.c.execute(sql.replace('%s','?'),args)
    def fetchone(self):
        row=self.c.fetchone();return dict(row) if row is not None else None
class DB:
    def __init__(self):
        self.conn=sqlite3.connect(':memory:',check_same_thread=False);self.conn.row_factory=sqlite3.Row
        self.conn.executescript("""
          CREATE TABLE user(user_id TEXT PRIMARY KEY);
          INSERT INTO user VALUES('owner'),('other');
          CREATE TABLE quit(user_user_id TEXT);
          CREATE TABLE push_device(installation_id TEXT PRIMARY KEY,user_id TEXT,binding_id TEXT,fid TEXT,fid_hash TEXT UNIQUE,updated_at TEXT);
          CREATE TABLE push_outbox(id INTEGER PRIMARY KEY,event_key TEXT,installation_id TEXT,binding_id TEXT,user_id TEXT,target_code TEXT,
            status TEXT DEFAULT 'pending',attempts INTEGER DEFAULT 0,next_at TEXT,lease_id TEXT,lease_until TEXT,created_at TEXT,UNIQUE(event_key,installation_id));
        """)
    def cursor(self):return Cursor(self.conn)
    def begin(self):self.conn.execute('BEGIN')
    def commit(self):self.conn.commit()
    def rollback(self):self.conn.rollback()
class PushTests(unittest.TestCase):
    def setUp(self):
        p=patch.dict(os.environ,{'PUSH_ENABLED':'true'});p.start();self.addCleanup(p.stop)
        self.db=DB();self.addCleanup(self.db.conn.close)
        self.item=SimpleNamespace(inspect_code='INS1',inspect_requested_no='20261031000001',user_user_id='owner')
    def enqueue(self):
        self.db.begin()
        with self.db.cursor() as c:service.enqueue_inspection(c,self.item)
        self.db.commit()
    def status(self):return dict(self.db.conn.execute('SELECT * FROM push_outbox').fetchone())
    def test_sdk_message_uses_fid_and_generic_content(self):
        from services.push_worker import send
        data={'event_id':'inspection_complete:INS1','owner_id':'owner','target_type':'inspection_results','target_code':'20261031000001'}
        with patch('firebase_admin.get_app',return_value=Mock()),patch('firebase_admin.messaging.send',return_value='message-id') as sender:
            self.assertEqual(send(TOKEN,data),'message-id')
            message=sender.call_args.args[0]
            self.assertEqual(message.fid,TOKEN)
            self.assertIsNone(message.token)
            self.assertEqual(message.android.notification.channel_id,'inspection_updates')
            self.assertNotIn('reason',repr(message.data))

    def test_disabled_feature_does_not_touch_db(self):
        with patch.dict(os.environ,{'PUSH_ENABLED':'false'}):
            cursor=Mock();service.enqueue_inspection(cursor,self.item);cursor.execute.assert_not_called()
    def test_registration_rotation_and_owner_scoped_delete(self):
        service.register_device(self.db,A,'owner',TOKEN)
        first=self.db.conn.execute('SELECT binding_id FROM push_device').fetchone()[0]
        service.register_device(self.db,A,'owner',TOKEN+'new')
        self.assertEqual(first,self.db.conn.execute('SELECT binding_id FROM push_device').fetchone()[0])
        service.unregister_device(self.db,A,'other')
        self.assertEqual(self.db.conn.execute('SELECT COUNT(*) FROM push_device').fetchone()[0],1)
        service.register_device(self.db,A,'other',TOKEN+'new')
        self.assertNotEqual(first,self.db.conn.execute('SELECT binding_id FROM push_device').fetchone()[0])
    def test_enqueue_is_transactional_deduplicated_and_excludes_internal_reason(self):
        service.register_device(self.db,A,'owner',TOKEN)
        self.enqueue();self.enqueue()
        self.assertEqual(self.db.conn.execute('SELECT COUNT(*) FROM push_outbox').fetchone()[0],1)
        send=Mock();self.assertTrue(process_one(self.db,send));self.assertEqual(self.status()['status'],'sent')
        payload=send.call_args.args[1]
        self.assertEqual(payload['target_code'],'20261031000001')
        self.assertEqual(payload['owner_id'],'owner')
        self.assertNotIn('grade',repr(payload));self.assertNotIn('reason',repr(payload))
        self.assertFalse(process_one(self.db,send));send.assert_called_once()
    def test_enqueue_rolls_back_with_business_transaction(self):
        service.register_device(self.db,A,'owner',TOKEN)
        self.db.begin()
        with self.db.cursor() as c:service.enqueue_inspection(c,self.item)
        self.db.rollback()
        self.assertEqual(self.db.conn.execute('SELECT COUNT(*) FROM push_outbox').fetchone()[0],0)
    def test_account_switch_and_quit_suppress_old_delivery(self):
        for operation in ['switch','quit']:
            with self.subTest(operation=operation):
                self.db.conn.execute('DELETE FROM push_outbox');self.db.conn.execute('DELETE FROM quit');self.db.commit()
                service.register_device(self.db,A,'owner',TOKEN);self.enqueue()
                if operation=='switch':service.register_device(self.db,A,'other',TOKEN)
                else:self.db.conn.execute("INSERT INTO quit VALUES('owner')");self.db.commit()
                sender=Mock();process_one(self.db,sender)
                sender.assert_not_called();self.assertEqual(self.status()['status'],'skipped')
    def test_latest_fid_is_used_and_transient_failure_retries(self):
        service.register_device(self.db,A,'owner',TOKEN);self.enqueue()
        service.register_device(self.db,A,'owner',TOKEN+'new')
        sender=Mock(side_effect=RuntimeError('do not log credentials'))
        process_one(self.db,sender)
        self.assertEqual(sender.call_args.args[0],TOKEN+'new')
        self.assertEqual(self.status()['status'],'pending');self.assertEqual(self.status()['attempts'],1)
        self.db.conn.execute("UPDATE push_outbox SET next_at=datetime('now','-1 minute')");self.db.commit()
        process_one(self.db,Mock());self.assertEqual(self.status()['status'],'sent')
    def test_invalid_fid_is_removed(self):
        from firebase_admin.messaging import UnregisteredError
        service.register_device(self.db,A,'owner',TOKEN);self.enqueue()
        process_one(self.db,Mock(side_effect=UnregisteredError('expired')))
        self.assertEqual(self.status()['status'],'failed')
        self.assertEqual(self.db.conn.execute('SELECT COUNT(*) FROM push_device').fetchone()[0],0)
    def test_crashed_final_attempt_becomes_failed(self):
        service.register_device(self.db,A,'owner',TOKEN);self.enqueue()
        self.db.conn.execute("UPDATE push_outbox SET attempts=5,status='sending',lease_until=datetime('now','-1 minute')");self.db.commit()
        self.assertFalse(process_one(self.db,Mock()));self.assertEqual(self.status()['status'],'failed')
    def test_api_owner_comes_from_login_not_body(self):
        app=FastAPI();app.include_router(router)
        app.dependency_overrides[get_db]=lambda:self.db
        app.dependency_overrides[get_current_user]=lambda:SimpleNamespace(user_id='owner')
        with TestClient(app) as client:
            result=client.put('/push/devices/'+A,json={'fid':TOKEN})
            self.assertEqual(result.status_code,200,result.text)
            self.assertNotIn(TOKEN,result.text)
            self.assertEqual(client.put('/push/devices/'+A,json={'fid':TOKEN,'user_id':'other'}).status_code,422)
