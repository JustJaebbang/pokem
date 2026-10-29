from contextlib import contextmanager

from fastapi import HTTPException

from database import get_connection
from security import decode_access_token
from services.chat_room_service import require_room_participant
from services.chat_service import create_chat


class ChatSocketBackend:
    @contextmanager
    def connection(self):
        # 소켓 수명 동안 DB 연결을 점유하지 않고 작업별로 열고 닫습니다.
        db = get_connection()
        try:
            yield db
        finally:
            db.close()

    def _authorize(self, db, room_id, token):
        claims = decode_access_token(token)
        if claims["role"] != "user":
            raise HTTPException(status_code=403, detail="일반 사용자 계정이 필요합니다.")
        with db.cursor() as cursor:
            cursor.execute(
                """
                SELECT user_id
                FROM `user`
                WHERE user_id = %s
                """, (claims["sub"],),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=401, detail="유효한 계정을 찾을 수 없습니다.")
            require_room_participant(cursor, room_id, claims["sub"])
        return claims

    def authorize(self, room_id, token):
        with self.connection() as db:
            return self._authorize(db, room_id, token)

    def save(self, room_id, token, chat):
        with self.connection() as db:
            claims = self._authorize(db, room_id, token)
            return create_chat(db, room_id, chat, claims["sub"])


def get_chat_socket_backend():
    return ChatSocketBackend()
