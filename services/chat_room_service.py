from services.sale_registration_service import get_sale_registrations
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi import HTTPException

from schemas.chat_room import ChatRoomResponse


def require_room_participant(cursor, room_id: str, user_id: str, lock=False):
    query = """
        SELECT *
        FROM chat_room
        WHERE chat_room_id = %s
    """
    if lock:
        query += "\n FOR UPDATE"
    cursor.execute(query, (room_id,))
    room = cursor.fetchone()
    if room is None:
        raise HTTPException(status_code=404, detail="채팅방을 찾을 수 없습니다.")
    if user_id not in (room["inquirer_user_id"], room["seller_user_id"]):
        raise HTTPException(status_code=403, detail="채팅방 참여자만 접근할 수 있습니다.")
    return room


def create_chat_room(db, product_code: str, inquirer_id: str) -> tuple[ChatRoomResponse, bool]:
    try:
        db.begin()
        with db.cursor() as cursor:
            posts = get_sale_registrations(cursor, product_code)
            if len(posts) != 1:
                raise HTTPException(status_code=404, detail="상품의 판매등록 정보를 찾을 수 없습니다.")
            seller_id = posts[0]["user_user_id"]
            if inquirer_id == seller_id:
                raise HTTPException(status_code=409, detail="본인 상품에는 문의 채팅방을 열 수 없습니다.")
            # 거래 기능과 동일하게 정렬된 사용자 → 상품 → 판매등록 → 방 순으로 잠급니다.
            cursor.execute(
                """
                SELECT user_id
                FROM `user`
                WHERE user_id IN (%s, %s)
                ORDER BY user_id
                FOR UPDATE
                """, (inquirer_id, seller_id),
            )
            users = {row["user_id"] for row in cursor.fetchall()}
            if inquirer_id not in users or seller_id not in users:
                raise HTTPException(status_code=409, detail="문의자 또는 판매자 계정을 확인해주세요.")
            cursor.execute(
                """
                SELECT sell_product_title, sell_product_sell_status
                FROM sell_product
                WHERE sell_product_code = %s
                FOR UPDATE
                """, (product_code,),
            )
            product = cursor.fetchone()
            if product is None:
                raise HTTPException(status_code=404, detail="판매상품을 찾을 수 없습니다.")
            posts = get_sale_registrations(cursor, product_code)
            if len(posts) != 1 or posts[0]["user_user_id"] != seller_id:
                raise HTTPException(status_code=409, detail="판매등록 정보가 변경되었습니다.")
            cursor.execute(
                """
                SELECT *
                FROM chat_room
                WHERE sell_product_sell_product_code = %s AND inquirer_user_id = %s
                FOR UPDATE
                """, (product_code, inquirer_id),
            )
            existing = cursor.fetchone()
            if existing is not None:
                if existing["seller_user_id"] != seller_id:
                    raise HTTPException(status_code=409, detail="기존 채팅방의 판매자 정보를 확인해주세요.")
                result = ChatRoomResponse(**existing)
                created = False
            else:
                if product["sell_product_sell_status"] != "판매중":
                    raise HTTPException(status_code=409, detail="판매 중인 상품에만 새 문의를 시작할 수 있습니다.")
                result = ChatRoomResponse(
                    chat_room_id="CR_" + uuid4().hex,
                    chat_room_name=(product["sell_product_title"] or "상품 문의")[:45],
                    chat_room_status="대화중",
                    chat_room_date=datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds"),
                    sell_product_sell_product_code=product_code,
                    inquirer_user_id=inquirer_id, seller_user_id=seller_id,
                )
                cursor.execute(
                    """
                    INSERT INTO chat_room (
                        chat_room_id, chat_room_name, chat_room_status, chat_room_date,
                        sell_product_sell_product_code, inquirer_user_id, seller_user_id
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """, (result.chat_room_id, result.chat_room_name, result.chat_room_status,
                          result.chat_room_date, product_code, inquirer_id, seller_id),
                )
                created = True
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result, created


# limit은 가져오는 채팅방 개수, offset은 건너뛰는 채팅방 개수
def get_chat_room(db, user_id: str, limit: int = 50, offset: int = 0):
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM chat_room
            WHERE inquirer_user_id = %s OR seller_user_id = %s
            ORDER BY chat_room_date DESC, chat_room_id DESC
            LIMIT %s OFFSET %s
            """, (user_id, user_id, limit, offset),
        )
        rows = cursor.fetchall()
    return [ChatRoomResponse(**row) for row in rows]


def get_chat_room_id(db, room_id: str, user_id: str):
    with db.cursor() as cursor:
        room = require_room_participant(cursor, room_id, user_id)
    return ChatRoomResponse(**room)
