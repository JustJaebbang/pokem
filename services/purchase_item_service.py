from datetime import datetime, timedelta, timezone

from fastapi import HTTPException

from schemas.purchase_item import PurchaseItemCreate, PurchaseItemResponse


# 구매 기록과 거래중 상태를 함께 저장합니다. 거래완료일은 구매확정 시 기록합니다.
def create_purchase_item(db, purchase: PurchaseItemCreate) -> PurchaseItemResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute(
                """
                SELECT user_id
                FROM `user`
                WHERE user_id = %s
                FOR UPDATE
                """,
                (purchase.user_user_id,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

            # 상품 행 잠금으로 같은 상품의 동시 구매를 직렬화합니다.
            cursor.execute(
                """
                SELECT sell_product_sell_status
                FROM sell_product
                WHERE sell_product_code = %s
                FOR UPDATE
                """,
                (purchase.sell_product_sell_product_code,),
            )
            product = cursor.fetchone()
            if product is None:
                raise HTTPException(status_code=404, detail="판매상품을 찾을 수 없습니다.")
            if product["sell_product_sell_status"] != "판매중":
                raise HTTPException(status_code=409, detail="판매 중인 상품만 구매할 수 있습니다.")

            cursor.execute(
                """
                SELECT user_user_id, post_item_complete_date
                FROM post_item
                WHERE sell_product_sell_product_code = %s
                FOR UPDATE
                """,
                (purchase.sell_product_sell_product_code,),
            )
            posts = cursor.fetchall()
            if len(posts) != 1:
                raise HTTPException(status_code=409, detail="상품의 판매등록 정보를 확인해주세요.")
            if posts[0]["user_user_id"] == purchase.user_user_id:
                raise HTTPException(status_code=409, detail="본인이 등록한 상품은 구매할 수 없습니다.")
            if posts[0]["post_item_complete_date"]:
                raise HTTPException(status_code=409, detail="이미 판매가 완료된 상품입니다.")

            cursor.execute(
                """
                SELECT purchase_item_code
                FROM purchase_item
                WHERE sell_product_sell_product_code = %s
                FOR UPDATE
                """,
                (purchase.sell_product_sell_product_code,),
            )
            if cursor.fetchone() is not None:
                raise HTTPException(status_code=409, detail="이미 구매 기록이 있는 상품입니다.")

            purchased_at = datetime.now(timezone(timedelta(hours=9)))
            now = purchased_at.isoformat(timespec="seconds")
            result = PurchaseItemResponse(
                purchase_item_code=(
                    f"{purchase.sell_product_sell_product_code}_"
                    f"{purchased_at.strftime('%Y%m%d%H%M%S%f')}"
                ),
                user_user_id=purchase.user_user_id,
                purchase_item_date=now,
                sell_product_sell_product_code=purchase.sell_product_sell_product_code,
            )
            cursor.execute(
                """
                INSERT INTO purchase_item (
                    purchase_item_code,
                    user_user_id,
                    purchase_item_date,
                    sell_product_sell_product_code
                )
                VALUES (%s, %s, %s, %s)
                """,
                (result.purchase_item_code, result.user_user_id,
                 result.purchase_item_date, result.sell_product_sell_product_code),
            )
            cursor.execute(
                """
                UPDATE sell_product
                SET sell_product_sell_status = %s
                WHERE sell_product_code = %s
                """,
                ("거래중", purchase.sell_product_sell_product_code),
            )
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result


def get_purchase_item(db, user_id: str) -> list[PurchaseItemResponse]:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT user_id
            FROM `user`
            WHERE user_id = %s
            """,
            (user_id,),
        )
        if cursor.fetchone() is None:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
        cursor.execute(
            """
            SELECT *
            FROM purchase_item
            WHERE user_user_id = %s
            ORDER BY purchase_item_date DESC, purchase_item_code DESC
            """,
            (user_id,),
        )
        rows = cursor.fetchall()
    return [PurchaseItemResponse(**row) for row in rows]


def get_purchase_item_code(db, purchase_item_code: str) -> PurchaseItemResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM purchase_item
            WHERE purchase_item_code = %s
            """,
            (purchase_item_code,),
        )
        row = cursor.fetchone()
    return PurchaseItemResponse(**row) if row else None
