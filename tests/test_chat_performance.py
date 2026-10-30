import unittest
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
from schemas.chat import ChatCreate
from services.chat_socket_backend import ChatSocketBackend
from services import chat_connection_pool as pool


class ChatPerformanceTests(unittest.TestCase):
    def test_authorization_checks_account_room_and_membership_in_one_query(self):
        claims = {'sub': 'buyer', 'role': 'user'}
        cases = [(None, 401), ({'chat_room_id': None}, 404),
                 ({'chat_room_id': 'room', 'inquirer_user_id': 'other', 'seller_user_id': 'seller'}, 403),
                 ({'chat_room_id': 'room', 'inquirer_user_id': 'buyer', 'seller_user_id': 'seller'}, None)]
        for row, status in cases:
            with self.subTest(status=status):
                db = MagicMock()
                cursor = db.cursor.return_value.__enter__.return_value
                cursor.fetchone.return_value = row
                with patch('services.chat_socket_backend.decode_access_token', return_value=claims):
                    if status:
                        with self.assertRaises(HTTPException) as error:
                            ChatSocketBackend()._authorize(db, 'room', 'token')
                        self.assertEqual(error.exception.status_code, status)
                    else:
                        self.assertEqual(ChatSocketBackend()._authorize(db, 'room', 'token'), claims)
                cursor.execute.assert_called_once()
                self.assertEqual(cursor.execute.call_args.args[1], ('room', 'buyer'))

    def test_save_uses_transaction_authorization_and_returns_connection(self):
        db = MagicMock()
        chat = ChatCreate(chat_contents='hello')
        with patch('services.chat_socket_backend.decode_access_token', return_value={'sub': 'buyer', 'role': 'user'}), \
             patch('services.chat_socket_backend.get_chat_connection', return_value=db), \
             patch('services.chat_socket_backend.create_chat', side_effect=HTTPException(403)) as create:
            with self.assertRaises(HTTPException):
                ChatSocketBackend().save('room', 'token', chat)
            create.assert_called_once_with(db, 'room', chat, 'buyer', missing_user_status=401)
            db.close.assert_called_once()

    def test_manager_cannot_save(self):
        with patch('services.chat_socket_backend.decode_access_token', return_value={'sub': 'manager', 'role': 'manager'}), \
             patch('services.chat_socket_backend.get_chat_connection') as connect:
            with self.assertRaises(HTTPException) as error:
                ChatSocketBackend().save('room', 'token', ChatCreate(chat_contents='hello'))
            self.assertEqual(error.exception.status_code, 403)
            connect.assert_not_called()

    def test_pool_is_lazy_bounded_and_connections_are_exclusive(self):
        with patch.object(pool, '_pool', None), patch.object(pool, 'PooledDB') as factory, \
             patch.object(pool, 'get_connection_options', return_value={}), \
             patch.dict('os.environ', {'CHAT_DB_POOL_SIZE': '8'}):
            factory.assert_not_called()
            pool.get_chat_connection()
            pool.get_chat_connection()
            factory.assert_called_once()
            options = factory.call_args.kwargs
            self.assertEqual(options['maxconnections'], 8)
            self.assertEqual(options['maxshared'], 0)
            self.assertTrue(options['reset'])
            self.assertEqual(options['ping'], 1)
            self.assertEqual(factory.return_value.connection.call_count, 2)
            factory.return_value.connection.assert_called_with(shareable=False)


class ChatSocketFlowTests(unittest.TestCase):
    def test_multiple_messages_are_saved_then_delivered_without_extra_sender_lookup(self):
        from datetime import datetime, timezone
        from fastapi import FastAPI
        from fastapi.testclient import TestClient
        from routers.chat_socket import router
        from schemas.chat import ChatResponse
        from security import create_access_token, decode_access_token
        from services.chat_socket_backend import get_chat_socket_backend

        token, _ = create_access_token('buyer', 'user')
        backend = MagicMock()
        backend.authorize.return_value = decode_access_token(token)
        def save(room, token, chat):
            return ChatResponse(chat_seq=backend.save.call_count, chat_type='text',
                                chat_contents=chat.chat_contents, chat_time=datetime.now(timezone.utc),
                                chat_room_chat_room_id=room, user_user_id='buyer')
        backend.save.side_effect = save
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_chat_socket_backend] = lambda: backend
        with TestClient(app) as client:
            with client.websocket_connect('/chat_room/room/ws') as socket:
                socket.send_json({'type': 'auth', 'access_token': token})
                self.assertEqual(socket.receive_json()['type'], 'ready')
                for text in ('hello', 'again'):
                    socket.send_json({'chat_contents': text})
                    received = socket.receive_json()
                    self.assertEqual(received['type'], 'message')
                    self.assertEqual(received['data']['chat_contents'], text)
                # Initial authorization + recipient checks. No duplicate sender DB lookup.
                self.assertEqual(backend.authorize.call_count, 3)
                self.assertEqual(backend.save.call_count, 2)
                backend.save.side_effect = HTTPException(403, 'forbidden')
                socket.send_json({'chat_contents': 'blocked'})
                self.assertEqual(socket.receive_json()['status'], 403)
                self.assertEqual(socket.receive()['code'], 1008)


if __name__ == '__main__':
    unittest.main()
