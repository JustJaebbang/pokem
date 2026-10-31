import sqlite3
import unittest
from unittest.mock import patch
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from dependencies import get_current_account
from schemas.auth import LoginRequest
from schemas.chat import ChatCreate
from schemas.user import UserQuitRequest
from services import user_service
from services.chat_service import create_chat
from services.chat_socket_backend import ChatSocketBackend


class Cursor:
    def __init__(self, conn):
        self.cursor = conn.cursor()
    def __enter__(self): return self
    def __exit__(self, *args): self.cursor.close()
    def execute(self, sql, args=()):
        if sql.strip().startswith("SET SESSION"): return
        self.cursor.execute(sql.replace("FOR UPDATE", "").replace("%s", "?"), args)
    def fetchone(self):
        row = self.cursor.fetchone()
        return dict(row) if row is not None else None
    def fetchall(self): return [dict(row) for row in self.cursor.fetchall()]


class DB:
    def __init__(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.row_factory = sqlite3.Row
        self.conn.executescript("""
          PRAGMA foreign_keys=ON;
          CREATE TABLE user(user_id TEXT PRIMARY KEY, user_password TEXT, user_nickname TEXT,
            user_name TEXT, user_phone TEXT, user_email TEXT, user_address TEXT, user_money INTEGER);
          CREATE TABLE quit(user_user_id TEXT PRIMARY KEY REFERENCES user(user_id),quit_date TEXT,quit_reason TEXT);
          CREATE TABLE history(code TEXT, user_id TEXT REFERENCES user(user_id));
          CREATE TABLE chat_room(chat_room_id TEXT,inquirer_user_id TEXT,seller_user_id TEXT);
          INSERT INTO user VALUES('owner','hash','nickname','name','010','mail','address',0);
          INSERT INTO history VALUES('TRADE1','owner');
          INSERT INTO chat_room VALUES('ROOM','owner','seller');
          ALTER TABLE user ADD COLUMN user_profile_image TEXT;
        """)
    def cursor(self): return Cursor(self.conn)
    def begin(self): self.conn.execute("BEGIN")
    def commit(self): self.conn.commit()
    def rollback(self): self.conn.rollback()


class QuitAuthenticationTests(unittest.TestCase):
    def setUp(self):
        self.db = DB()
        self.addCleanup(self.db.conn.close)
    def withdraw(self):
        return user_service.delete_user_id(self.db, UserQuitRequest(quit_reason="done"), "owner")
    def test_user_and_history_are_preserved_with_quit_record(self):
        self.withdraw()
        self.assertEqual(self.db.conn.execute("SELECT COUNT(*) FROM user").fetchone()[0], 1)
        self.assertEqual(self.db.conn.execute("SELECT COUNT(*) FROM history").fetchone()[0], 1)
        self.assertEqual(self.db.conn.execute("SELECT quit_reason FROM quit").fetchone()[0], "done")
        self.assertIsNone(user_service.get_user_id(self.db,"owner"))
    def test_correct_password_cannot_login_after_quit(self):
        login=LoginRequest(login_id="owner",password="correct")
        with patch("services.user_service.verify_password",return_value=True):
            self.assertEqual(user_service.login_user(self.db,login).account.user_id,"owner")
            self.withdraw()
            with self.assertRaises(HTTPException) as e: user_service.login_user(self.db,login)
            self.assertEqual(e.exception.status_code,401)
    def test_existing_token_is_rejected_on_next_http_request(self):
        credentials=HTTPAuthorizationCredentials(scheme="Bearer",credentials="issued-before-quit")
        with patch("dependencies.decode_access_token",return_value={"sub":"owner","role":"user"}):
            self.assertEqual(get_current_account(credentials,self.db).account.user_id,"owner")
            self.withdraw()
            with self.assertRaises(HTTPException) as e: get_current_account(credentials,self.db)
            self.assertEqual(e.exception.status_code,401)
    def test_socket_authorization_and_message_save_reject_retired_account(self):
        with patch("services.chat_socket_backend.decode_access_token",return_value={"sub":"owner","role":"user"}):
            self.assertEqual(ChatSocketBackend()._authorize(self.db,"ROOM","token")["sub"],"owner")
            self.withdraw()
            with self.assertRaises(HTTPException) as e: ChatSocketBackend()._authorize(self.db,"ROOM","token")
            self.assertEqual(e.exception.status_code,401)
        with self.assertRaises(HTTPException) as e:
            create_chat(self.db,"ROOM",ChatCreate(chat_contents="blocked"),"owner",missing_user_status=401)
        self.assertEqual(e.exception.status_code,401)
    def test_second_quit_does_not_create_another_record(self):
        self.withdraw()
        with self.assertRaises(HTTPException): self.withdraw()
        self.assertEqual(self.db.conn.execute("SELECT COUNT(*) FROM quit").fetchone()[0],1)
