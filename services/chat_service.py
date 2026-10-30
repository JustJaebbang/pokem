from datetime import datetime, timezone

from fastapi import HTTPException

from schemas.chat import ChatCreate, ChatResponse
from services.chat_room_service import require_room_participant


def create_chat(db, room_id: str, chat: ChatCreate, user_id: str, *, missing_user_status: int = 404) -> ChatResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute(
                """
                SET SESSION time_zone = '+00:00'
                """
            )
            cursor.execute(
                """
                SELECT user_id
                FROM `user`
                WHERE user_id = %s
                FOR UPDATE
                """, (user_id,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=missing_user_status, detail="사용자를 찾을 수 없습니다.")
            room = require_room_participant(cursor, room_id, user_id, lock=True)
            if room["chat_room_status"] != "대화중":
                raise HTTPException(status_code=409, detail="종료된 채팅방에는 메시지를 보낼 수 없습니다.")
            now = datetime.now(timezone.utc).replace(microsecond=0)
            cursor.execute(
                """
                INSERT INTO chat (
                    chat_type, chat_contents, chat_time, chat_room_chat_room_id, user_user_id
                )
                VALUES (%s, %s, %s, %s, %s)
                """, (chat.chat_type, chat.chat_contents, now.replace(tzinfo=None), room_id, user_id),
            )
            result = ChatResponse(
                chat_seq=cursor.lastrowid, chat_type=chat.chat_type, chat_contents=chat.chat_contents,
                chat_time=now, chat_room_chat_room_id=room_id, user_user_id=user_id,
            )
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result


def get_chat(db, room_id: str, user_id: str, after_chat_seq: int = 0, limit: int = 50):
    with db.cursor() as cursor:
        cursor.execute(
            """
            SET SESSION time_zone = '+00:00'
            """
        )
        require_room_participant(cursor, room_id, user_id)
        cursor.execute(
            """
            SELECT *
            FROM chat
            WHERE chat_room_chat_room_id = %s AND chat_seq > %s
            ORDER BY chat_seq ASC
            LIMIT %s
            """, (room_id, after_chat_seq, limit),
        )
        rows = cursor.fetchall()
    return [ChatResponse(**row) for row in rows]
