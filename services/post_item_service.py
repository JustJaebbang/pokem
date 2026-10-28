from fastapi import HTTPException

from schemas.post_item import PostItemResponse

from datetime import datetime
from zoneinfo import ZoneInfo

# 판매등록 정보 DB 저장
def insert_post_item(db, user_id, region, product_code):
    now = datetime.now(ZoneInfo("Asia/Seoul"))

    post_item = {
        "post_item_code": (
            f"{product_code}_{now.strftime('%Y%m%d%H%M%S%f')}"
        ),
        "user_user_id": user_id,
        "post_item_post_date": now.strftime("%Y-%m-%d %H:%M:%S"),
        "post_item_complete_date": None,
        "post_item_region": region,
        "sell_product_sell_product_code": product_code,
    }

    with db.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO post_item (
                post_item_code,
                sell_product_sell_product_code,
                user_user_id,
                post_item_post_date,
                post_item_complete_date,
                post_item_region
            )
            VALUES (
                %(post_item_code)s,
                %(sell_product_sell_product_code)s,
                %(user_user_id)s,
                %(post_item_post_date)s,
                %(post_item_complete_date)s,
                %(post_item_region)s
            )
            """,
            post_item,
        )

    return post_item


# 전체 post_item 정보 가져오기
def get_post_item(db) -> list[PostItemResponse] | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM post_item
            """,
        )
        rows = cursor.fetchall()

    return [PostItemResponse(**row) for row in rows]


# post_item 정보 가져오기
def get_post_item_code(db, post_item_code: str) -> PostItemResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM post_item
            WHERE post_item_code = %s
            """,
            (post_item_code),
        )
        row = cursor.fetchone()

    return PostItemResponse(**row) if row else None