from datetime import datetime, timedelta, timezone

from fastapi import HTTPException

from schemas.wishlist import WishlistResponse


# 같은 사용자의 요청을 직렬화하여 사용자·상품별 중복 등록을 방지합니다.
# 다른 프로그램에서도 직접 INSERT한다면 DB에 복합 UNIQUE 제약이 필요합니다.
def set_wishlist(db, user_id: str, sell_product_code: str, is_wished: bool) -> WishlistResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute(
                """
                SELECT user_id 
                FROM `user` 
                WHERE user_id = %s FOR UPDATE
                """,
                (user_id,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

            cursor.execute(
                """
                SELECT sell_product_code 
                FROM sell_product 
                WHERE sell_product_code = %s FOR UPDATE
                """,
                (sell_product_code,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="판매상품을 찾을 수 없습니다.")

            cursor.execute(
                """
                SELECT * FROM wishlist
                WHERE user_user_id = %s AND sell_product_sell_product_code = %s
                FOR UPDATE
                """,
                (user_id, sell_product_code),
            )
            row = cursor.fetchone()
            if row is None and not is_wished:
                raise HTTPException(status_code=404, detail="관심상품 기록을 찾을 수 없습니다.")

            status = "관심" if is_wished else "해제"
            now = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds")
            if row is None:
                cursor.execute(
                    """
                    INSERT INTO wishlist (
                        wishlist_date, wishlist_status, wishlist_update,
                        user_user_id, sell_product_sell_product_code
                    ) VALUES (%s, %s, %s, %s, %s)
                    """,
                    (now, status, now, user_id, sell_product_code),
                )
                row = {
                    "wishlist_seq": cursor.lastrowid,
                    "wishlist_date": now,
                    "wishlist_status": status,
                    "wishlist_update": now,
                    "user_user_id": user_id,
                    "sell_product_sell_product_code": sell_product_code,
                }
            elif row["wishlist_status"] != status:
                cursor.execute(
                    """
                    UPDATE wishlist SET wishlist_status = %s, wishlist_update = %s
                    WHERE wishlist_seq = %s
                    """,
                    (status, now, row["wishlist_seq"]),
                )
                row = {**row, "wishlist_status": status, "wishlist_update": now}

            result = WishlistResponse(**row)
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result


# 하트가 켜진 관심상품만 반환합니다. 빈 목록은 []입니다.
def get_wishlist(db, user_id: str) -> list[WishlistResponse]:
    with db.cursor() as cursor:
        cursor.execute("SELECT user_id FROM `user` WHERE user_id = %s", (user_id,))
        if cursor.fetchone() is None:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
        cursor.execute(
            """
            SELECT * FROM wishlist
            WHERE user_user_id = %s AND wishlist_status = %s
            ORDER BY wishlist_update DESC, wishlist_seq DESC
            """,
            (user_id, "관심"),
        )
        rows = cursor.fetchall()
    return [WishlistResponse(**row) for row in rows]
