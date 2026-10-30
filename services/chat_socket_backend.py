from contextlib import contextmanager

from fastapi import HTTPException

from services.chat_connection_pool import get_chat_connection
from security import decode_access_token
from services.chat_service import create_chat


class ChatSocketBackend:
    @contextmanager
    def connection(self):
        # 작업이 끝나면 연결을 풀에 반환합니다.
        db = get_chat_connection()
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
                SELECT u.user_id, r.chat_room_id, r.inquirer_user_id, r.seller_user_id
                FROM `user` u
                LEFT JOIN chat_room r ON r.chat_room_id = %s
                WHERE u.user_id = %s
                """, (room_id, claims["sub"]),
            )
            row = cursor.fetchone()
            if row is None:
                raise HTTPException(status_code=401, detail="유효한 계정을 찾을 수 없습니다.")
            if row["chat_room_id"] is None:
                raise HTTPException(status_code=404, detail="채팅방을 찾을 수 없습니다.")
            if claims["sub"] not in (row["inquirer_user_id"], row["seller_user_id"]):
                raise HTTPException(status_code=403, detail="채팅방 참여자만 접근할 수 있습니다.")
        return claims

    def authorize(self, room_id, token):
        with self.connection() as db:
            return self._authorize(db, room_id, token)

    def save(self, room_id, token, chat):
        claims = decode_access_token(token)
        if claims["role"] != "user":
            raise HTTPException(status_code=403, detail="일반 사용자 계정이 필요합니다.")
        with self.connection() as db:
            # 저장 트랜잭션 안에서 계정과 참여 권한을 잠금과 함께 검사합니다.
            return create_chat(db, room_id, chat, claims["sub"], missing_user_status=401)


def get_chat_socket_backend():
    return ChatSocketBackend()
