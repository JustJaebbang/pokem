import os
import sqlite3
import unittest
from unittest.mock import patch
from fastapi import HTTPException
from fastapi.testclient import TestClient
from database import get_db
from main import app
from schemas.account_recovery import RecoveryRequest, RecoveryComplete
from security import hash_password, verify_password
from services import account_recovery_service as service

class Cursor:
    def __init__(self, conn): self.c = conn.cursor()
    def __enter__(self): return self
    def __exit__(self, *args): self.c.close()
    def execute(self, sql, args=()): self.c.execute(sql.replace('%s', '?').replace(' FOR UPDATE', ''), args)
    def fetchall(self): return [dict(r) for r in self.c.fetchall()]

class DB:
    def __init__(self):
        self.conn = sqlite3.connect(':memory:', check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.conn.executescript("CREATE TABLE user(user_id TEXT PRIMARY KEY, user_email TEXT,user_password TEXT); CREATE TABLE quit(user_user_id TEXT);")
        self.original = hash_password('old-password')
        self.conn.execute('INSERT INTO user VALUES(?,?,?)', ('tester', 'test@example.com', self.original))
        self.conn.commit()
    def cursor(self): return Cursor(self.conn)
    def begin(self): self.conn.execute('BEGIN')
    def commit(self): self.conn.commit()
    def rollback(self): self.conn.rollback()

class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.db = DB(); self.addCleanup(self.db.conn.close)
        service._challenges.clear(); service._rates.clear()
        self.addCleanup(service._challenges.clear); self.addCleanup(service._rates.clear)
        self.mail = []
        p = patch('services.recovery_mail_service.mail_settings', return_value=('host',587,'from@example.com','starttls'))
        p.start(); self.addCleanup(p.stop)
        p = patch('services.recovery_mail_service.send_code', side_effect=lambda email,code: self.mail.append((email,code)))
        p.start(); self.addCleanup(p.stop)
        p = patch.dict(os.environ, {'JWT_SECRET_KEY':'r'*64})
        p.start(); self.addCleanup(p.stop)
    def request(self, purpose='find_id', email='test@example.com', user_id=None):
        return service.request_code(self.db, RecoveryRequest(purpose=purpose,email=email,user_id=user_id), '127.0.0.1')['challenge_id']
    def finish(self, key, code=None, password=None):
        return service.complete(self.db, RecoveryComplete(challenge_id=key, code=code or self.mail[-1][1], new_password=password))
    def test_id_lookup_returns_only_ids_after_proof_and_is_single_use(self):
        key = self.request()
        self.assertNotIn(self.mail[0][1], repr(service._challenges))
        self.assertEqual(self.finish(key)['user_ids'], ['tester'])
        with self.assertRaises(HTTPException): self.finish(key)
    def test_password_reset_changes_hash_and_invalidates_other_challenge_binding(self):
        key=self.request('reset_password', user_id='tester')
        self.finish(key,password='new-password')
        row=self.db.conn.execute('SELECT user_password FROM user').fetchone()
        self.assertTrue(verify_password('new-password',row[0]))
        self.assertFalse(verify_password('old-password',row[0]))
        self.assertNotEqual(row[0],'new-password')
    def test_wrong_code_locks_after_five_attempts(self):
        key=self.request(); good=self.mail[-1][1]; wrong='000001' if good=='000000' else '000000'
        for _ in range(5):
            with self.assertRaises(HTTPException): self.finish(key,wrong)
        with self.assertRaises(HTTPException): self.finish(key,good)
    def test_expiry_and_resend_rate(self):
        key=self.request()
        with self.assertRaises(HTTPException) as context:self.request()
        self.assertEqual(context.exception.status_code,429)
        service._challenges[key]['expires']=0
        with self.assertRaises(HTTPException): self.finish(key)
    def test_unknown_and_withdrawn_accounts_do_not_send_mail_or_disclose_ids(self):
        key=self.request(email='missing@example.com')
        self.assertEqual(self.mail,[])
        with self.assertRaises(HTTPException):self.finish(key,'123456')
        self.db.conn.execute('INSERT INTO quit VALUES(?)',('tester',));self.db.commit()
        self.request()
        self.assertEqual(self.mail,[])
    def test_wrong_reset_id_does_not_send_mail(self):
        self.request('reset_password',user_id='other')
        self.assertEqual(self.mail,[])
    def test_change_of_email_password_or_withdrawal_invalidates_proof(self):
        for change in ["UPDATE user SET user_email='other@example.com'", "UPDATE user SET user_password='changed'", "INSERT INTO quit VALUES('tester')"]:
            with self.subTest(change=change):
                service._rates.clear()
                self.db.conn.execute('DELETE FROM quit')
                self.db.conn.execute('UPDATE user SET user_email=?,user_password=?',('test@example.com',self.db.original));self.db.commit()
                key=self.request('reset_password',user_id='tester')
                self.db.conn.execute(change);self.db.commit()
                with self.assertRaises(HTTPException):self.finish(key,password='new-password')
    def test_hourly_email_and_ip_limits(self):
        for number in range(5):
            with patch('services.account_recovery_service.time.monotonic',return_value=10000+number*61):
                self.request()
        with patch('services.account_recovery_service.time.monotonic',return_value=10310):
            with self.assertRaises(HTTPException) as result:self.request()
            self.assertEqual(result.exception.status_code,429)
        service._rates.clear();service._challenges.clear()
        for number in range(20):self.request(email=f'unknown{number}@example.com')
        with self.assertRaises(HTTPException) as result:self.request(email='last@example.com')
        self.assertEqual(result.exception.status_code,429)

    def test_send_failure_cannot_leave_valid_challenge(self):
        with patch('services.recovery_mail_service.send_code',side_effect=HTTPException(503,'mail failed')):
            with self.assertRaises(HTTPException):self.request()
        self.assertEqual(service._challenges,{})
    def test_public_routes_validate_and_do_not_expose_code(self):
        previous=dict(app.dependency_overrides)
        self.addCleanup(lambda:(app.dependency_overrides.clear(),app.dependency_overrides.update(previous)))
        app.dependency_overrides[get_db]=lambda:self.db
        with TestClient(app) as client:
            result=client.post('/auth/recovery/request',json={'email':'test@example.com','purpose':'find_id'})
            self.assertEqual(result.status_code,200,result.text)
            self.assertEqual(result.headers['Cache-Control'],'no-store')
            self.assertEqual(set(result.json()),{'challenge_id','expires_in','retry_after','message'})
            result=client.post('/auth/recovery/complete',json={'challenge_id':result.json()['challenge_id'],'code':self.mail[-1][1]})
            self.assertEqual(result.json()['user_ids'],['tester'])
            self.assertEqual(client.post('/auth/recovery/request',json={'email':'bad','purpose':'find_id'}).status_code,422)

class RecoveryMailTests(unittest.TestCase):
    def test_missing_configuration_is_explicit_and_does_not_send(self):
        from services import recovery_mail_service as mail
        with patch.dict(os.environ, {'SMTP_HOST':'','SMTP_FROM':''}):
            with self.assertRaises(HTTPException) as result: mail.mail_settings()
            self.assertEqual(result.exception.status_code,503)
    def test_smtp_requires_tls_and_keeps_code_out_of_subject(self):
        from services import recovery_mail_service as mail
        env={'SMTP_HOST':'smtp.example.com','SMTP_FROM':'from@example.com','SMTP_SECURITY':'starttls','SMTP_PORT':'587','SMTP_USERNAME':'sender','SMTP_PASSWORD':'local-test'}
        with patch.dict(os.environ,env), patch('smtplib.SMTP') as smtp:
            mail.send_code('test@example.com','123456')
            client=smtp.return_value.__enter__.return_value
            client.starttls.assert_called_once()
            client.login.assert_called_once_with('sender','local-test')
            message=client.send_message.call_args.args[0]
            self.assertEqual(message['To'],'test@example.com')
            self.assertNotIn('123456',message['Subject'])
            self.assertIn('123456',message.get_content())
