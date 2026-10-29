from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.review import ReviewCreate, ReviewResponse


def create_review(db, review: ReviewCreate, user_id: str) -> ReviewResponse:
    purchase_code = review.purchase_item_purchase_item_code
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
                (user_id,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
            cursor.execute(
                """
                SELECT user_user_id, sell_product_sell_product_code, purchase_item_status, purchase_item_confirmed_at
                FROM purchase_item
                WHERE purchase_item_code = %s
                """,
                (purchase_code,),
            )
            purchase = cursor.fetchone()
            if purchase is None:
                raise HTTPException(status_code=404, detail="구매 정보를 찾을 수 없습니다.")
            if purchase["user_user_id"] != user_id:
                raise HTTPException(status_code=403, detail="본인이 구매한 거래에만 리뷰를 작성할 수 있습니다.")
            product_code = purchase["sell_product_sell_product_code"]
            # 구매확정과 동일하게 사용자 → 상품 → 구매 → 판매등록 순으로 잠금
            cursor.execute(
                """
                SELECT sell_product_code
                FROM sell_product
                WHERE sell_product_code = %s
                FOR UPDATE
                """,
                (product_code,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="판매상품을 찾을 수 없습니다.")
            cursor.execute(
                """
                SELECT user_user_id, sell_product_sell_product_code, purchase_item_status, purchase_item_confirmed_at
                FROM purchase_item
                WHERE purchase_item_code = %s
                FOR UPDATE
                """,
                (purchase_code,),
            )
            purchase = cursor.fetchone()
            if purchase is None:
                raise HTTPException(status_code=404, detail="구매 정보를 찾을 수 없습니다.")
            if purchase["user_user_id"] != user_id:
                raise HTTPException(status_code=403, detail="본인의 구매 건만 리뷰를 작성할 수 있습니다.")
            if purchase["sell_product_sell_product_code"] != product_code:
                raise HTTPException(status_code=409, detail="구매 정보가 변경되었습니다. 다시 확인해주세요.")
            if purchase["purchase_item_status"] != "구매확정" or not purchase["purchase_item_confirmed_at"]:
                raise HTTPException(status_code=409, detail="구매확정된 구매 건에만 리뷰를 작성할 수 있습니다.")
            cursor.execute(
                """
                SELECT post_item_code, user_user_id
                FROM post_item
                WHERE sell_product_sell_product_code = %s
                FOR UPDATE
                """,
                (product_code,),
            )
            posts = cursor.fetchall()
            if len(posts) != 1:
                raise HTTPException(status_code=409, detail="구매확정이 완료된 거래에만 리뷰를 작성할 수 있습니다.")
            if posts[0]["user_user_id"] == user_id:
                raise HTTPException(status_code=409, detail="본인 상품에는 구매 리뷰를 작성할 수 없습니다.")
            cursor.execute(
                """
                SELECT review_code
                FROM review
                WHERE purchase_item_purchase_item_code = %s
                FOR UPDATE
                """,
                (purchase_code,),
            )
            if cursor.fetchone() is not None:
                raise HTTPException(status_code=409, detail="이미 리뷰를 작성한 구매 건입니다.")

            written_at = datetime.now(timezone(timedelta(hours=9)))
            result = ReviewResponse(
                review_code=f"{purchase_code}_{written_at.strftime('%Y%m%d%H%M%S%f')}",
                purchase_item_purchase_item_code=purchase_code,
                review_contents=review.review_contents,
                review_rating=review.review_rating,
                review_date=written_at.isoformat(timespec="seconds"),
                user_user_id=user_id,
                sell_product_sell_product_code=product_code,
            )
            cursor.execute(
                """
                INSERT INTO review (
                    review_code,
                    purchase_item_purchase_item_code,
                    review_contents,
                    review_rating,
                    review_date,
                    user_user_id,
                    sell_product_sell_product_code
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (result.review_code, purchase_code, result.review_contents, result.review_rating,
                 result.review_date, user_id, product_code),
            )
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 리뷰를 작성한 구매 건입니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise
    return result


def get_review(db, sell_product_code: str | None = None) -> list[ReviewResponse]:
    with db.cursor() as cursor:
        if sell_product_code is None:
            cursor.execute(
                """
                SELECT *
                FROM review
                ORDER BY review_date DESC, review_code DESC
                """
            )
        else:
            cursor.execute(
                """
                SELECT *
                FROM review
                WHERE sell_product_sell_product_code = %s
                ORDER BY review_date DESC, review_code DESC
                """,
                (sell_product_code,),
            )
        rows = cursor.fetchall()
    return [ReviewResponse(**row) for row in rows]


def get_review_code(db, review_code: str) -> ReviewResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM review
            WHERE review_code = %s
            """,
            (review_code,),
        )
        row = cursor.fetchone()
    return ReviewResponse(**row) if row else None
