from services.sale_registration_service import get_sale_registrations, complete_sale_registration
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException

from schemas.purchase_item import PurchaseItemCreate, PurchaseItemResponse, PurchaseItemConfirmResponse
from services import cybermoney_pay_service


# 결제·구매 기록·거래중 상태를 하나의 트랜잭션으로 확정합니다. 거래완료일은 구매확정 시 기록합니다.
def create_purchase_item(db, purchase: PurchaseItemCreate) -> PurchaseItemResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute(
                """
                SELECT user_id, user_money
                FROM `user`
                WHERE user_id = %s
                FOR UPDATE
                """,
                (purchase.user_user_id,),
            )
            user = cursor.fetchone()
            if user is None:
                raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

            # 상품 행 잠금으로 같은 상품의 동시 구매를 직렬화합니다.
            cursor.execute(
                """
                SELECT sell_product_sell_status, sell_product_sell_price
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

            posts = get_sale_registrations(cursor, purchase.sell_product_sell_product_code)
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
                    AND purchase_item_status <> %s
                FOR UPDATE
                """,
                (purchase.sell_product_sell_product_code, "거래취소"),
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
            # 잔액 차감을 먼저 수행하며, 이후 저장 실패 시 이 차감도 롤백됩니다.
            balance = cybermoney_pay_service.deduct_cybermoney(
                db, purchase.user_user_id, product["sell_product_sell_price"], user["user_money"]
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
            # 결제 테이블이 구매 코드를 참조하므로 구매 INSERT 직후 결제를 기록합니다.
            cybermoney_pay_service.insert_cybermoney_pay(
                db=db,
                purchase_code=result.purchase_item_code,
                user_id=purchase.user_user_id,
                price=product["sell_product_sell_price"],
                balance=balance,
                paid_at=purchased_at,
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


# 구매확정의 모든 변경은 같은 연결로 수행하고 마지막에 한 번만 commit
def confirm_purchase_item(db, purchase_item_code: str, buyer_id: str) -> PurchaseItemConfirmResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute(
                """
                SELECT user_user_id, sell_product_sell_product_code, purchase_item_status, purchase_item_confirmed_at
                FROM purchase_item
                WHERE purchase_item_code = %s
                """,
                (purchase_item_code,),
            )
            purchase = cursor.fetchone()
            if purchase is None:
                raise HTTPException(status_code=404, detail="구매 정보를 찾을 수 없습니다.")
            if purchase["user_user_id"] != buyer_id:
                raise HTTPException(status_code=403, detail="본인의 구매 건만 확정할 수 있습니다.")
            product_code = purchase["sell_product_sell_product_code"]
            posts = get_sale_registrations(cursor, product_code)
            if len(posts) != 1:
                raise HTTPException(status_code=409, detail="판매등록 정보를 확인해주세요.")
            seller_id = posts[0]["user_user_id"]
            if seller_id == buyer_id:
                raise HTTPException(status_code=409, detail="본인 상품의 구매확정은 처리할 수 없습니다.")

            # 구매·충전과 같이 사용자 → 상품 순으로 잠금
            # 서로의 상품을 확정하는 요청도 같은 순서로 사용자 행을 잠금
            cursor.execute(
                """
                SELECT user_id, user_money
                FROM `user`
                WHERE user_id IN (%s, %s)
                ORDER BY user_id
                FOR UPDATE
                """,
                (buyer_id, seller_id),
            )
            users = {row["user_id"]: row for row in cursor.fetchall()}
            if buyer_id not in users or seller_id not in users:
                raise HTTPException(status_code=409, detail="구매자 또는 판매자 계정을 확인해주세요.")
            cursor.execute(
                """
                SELECT sell_product_sell_status
                FROM sell_product
                WHERE sell_product_code = %s
                FOR UPDATE
                """,
                (product_code,),
            )
            product = cursor.fetchone()
            if product is None:
                raise HTTPException(status_code=404, detail="판매상품을 찾을 수 없습니다.")
            if product["sell_product_sell_status"] != "거래중":
                raise HTTPException(status_code=409, detail="거래 중인 상품만 구매확정할 수 있습니다.")
            cursor.execute(
                """
                SELECT user_user_id, sell_product_sell_product_code, purchase_item_status, purchase_item_confirmed_at
                FROM purchase_item
                WHERE purchase_item_code = %s
                FOR UPDATE
                """,
                (purchase_item_code,),
            )
            purchase = cursor.fetchone()
            if purchase is None:
                raise HTTPException(status_code=404, detail="구매 정보를 찾을 수 없습니다.")
            if purchase["user_user_id"] != buyer_id or purchase["sell_product_sell_product_code"] != product_code:
                raise HTTPException(status_code=409, detail="구매 정보가 변경되었습니다. 다시 확인해주세요.")
            if purchase["purchase_item_status"] != "거래중" or purchase["purchase_item_confirmed_at"] is not None:
                raise HTTPException(status_code=409, detail="취소 요청 중이거나 이미 종료된 구매는 확정할 수 없습니다.")
            posts = get_sale_registrations(cursor, product_code)
            if len(posts) != 1 or posts[0]["user_user_id"] != seller_id:
                raise HTTPException(status_code=409, detail="판매등록 정보가 변경되었습니다.")
            post = posts[0]
            if post["post_item_complete_date"] is not None:
                raise HTTPException(status_code=409, detail="이미 구매확정된 상품입니다.")
            cursor.execute(
                """
                SELECT cybermoney_pay_code, cybermoney_pay_status, cybermoney_pay_price
                FROM cybermoney_pay
                WHERE purchase_item_purchase_item_code = %s
                FOR UPDATE
                """,
                (purchase_item_code,),
            )
            payments = cursor.fetchall()
            if len(payments) != 1 or payments[0]["cybermoney_pay_status"] != "결제완료":
                raise HTTPException(status_code=409, detail="결제 완료된 구매 건만 확정할 수 있습니다.")
            payment = payments[0]
            pay_code = payment["cybermoney_pay_code"]
            # 여기 부분 cybermoney_pay_cancel 구현 이후에 한번 더 확인
            cursor.execute(
                """
                SELECT cybermoney_pay_cancel_code
                FROM cybermoney_pay_cancel
                WHERE cybermoney_pay_cybermoney_pay_code = %s
                FOR UPDATE
                """,
                (pay_code,),
            )
            if cursor.fetchone() is not None:
                raise HTTPException(status_code=409, detail="취소 기록이 있는 결제는 구매확정할 수 없습니다.")
            cursor.execute(
                """
                SELECT cybermoney_give_code
                FROM cybermoney_give
                WHERE cybermoney_pay_code = %s
                FOR UPDATE
                """,
                (pay_code,),
            )
            if cursor.fetchone() is not None:
                raise HTTPException(status_code=409, detail="이미 지급 기록이 있는 결제입니다.")
            price = payment["cybermoney_pay_price"]
            if price is None or price <= 0:
                raise HTTPException(status_code=409, detail="실제 결제 금액을 확인해주세요.")
            if users[seller_id]["user_money"] + price > 2147483647:
                raise HTTPException(status_code=409, detail="판매자 잔액이 저장 가능한 최대 금액을 초과합니다.")

            confirmed_at = datetime.now(timezone(timedelta(hours=9)))
            now = confirmed_at.isoformat(timespec="seconds")
            result = PurchaseItemConfirmResponse(
                message="구매확정 및 판매자 지급이 완료되었습니다.",
                purchase_item_code=purchase_item_code,
                sell_product_code=product_code,
                seller_user_id=seller_id,
                cybermoney_pay_code=pay_code,
                cybermoney_give_code=(
                    f"{pay_code}_{confirmed_at.strftime('%Y%m%d%H%M%S%f')}"
                ),
                cybermoney_give_price=price,
                post_item_complete_date=now,
                sell_product_sell_status="거래완료",
            )
            cursor.execute(
                """
                UPDATE `user`
                SET user_money = user_money + %s
                WHERE user_id = %s
                """,
                (price, seller_id),
            )
            if cursor.rowcount != 1:
                raise HTTPException(status_code=409, detail="판매자 잔액을 변경할 수 없습니다.")
            cursor.execute(
                """
                INSERT INTO cybermoney_give (
                    cybermoney_give_code,
                    cybermoney_pay_code,
                    cybermoney_give_status,
                    cybermoney_give_date,
                    cybermoney_give_price
                )
                VALUES (%s, %s, %s, %s, %s)
                """,
                (result.cybermoney_give_code, pay_code, "지급완료", now, price),
            )
            complete_sale_registration(cursor, post, product_code, now)
            if cursor.rowcount != 1:
                raise HTTPException(status_code=409, detail="거래완료일을 변경할 수 없습니다.")
            cursor.execute(
                """
                UPDATE purchase_item
                SET purchase_item_status = %s, purchase_item_confirmed_at = %s
                WHERE purchase_item_code = %s AND purchase_item_status = %s
                """,
                ("구매확정", now, purchase_item_code, "거래중"),
            )
            if cursor.rowcount != 1:
                raise HTTPException(status_code=409, detail="구매 상태가 변경되었습니다.")
            cursor.execute(
                """
                UPDATE sell_product
                SET sell_product_sell_status = %s
                WHERE sell_product_code = %s
                    AND sell_product_sell_status = %s
                """,
                ("거래완료", product_code, "거래중"),
            )
            if cursor.rowcount != 1:
                raise HTTPException(status_code=409, detail="상품 상태를 변경할 수 없습니다.")
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result
