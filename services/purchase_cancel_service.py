from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.purchase_cancel import PurchaseCancelResponse


def _now():
    return datetime.now(timezone(timedelta(hours=9)))


def _require(condition, detail, status=409):
    if not condition:
        raise HTTPException(status_code=status, detail=detail)


def _lock_trade(cursor, purchase_code, actor_id, actor_role):
    cursor.execute(
        """
        SELECT *
        FROM purchase_item
        WHERE purchase_item_code = %s
        """, (purchase_code,),
    )
    initial = cursor.fetchone()
    _require(initial is not None, "구매 정보를 찾을 수 없습니다.", 404)
    buyer_id = initial["user_user_id"]
    product_code = initial["sell_product_sell_product_code"]
    cursor.execute(
        """
        SELECT user_user_id
        FROM post_item
        WHERE sell_product_sell_product_code = %s
        """, (product_code,),
    )
    posts = cursor.fetchall()
    _require(len(posts) == 1, "판매등록 정보를 확인해주세요.")
    seller_id = posts[0]["user_user_id"]
    _require(buyer_id != seller_id, "구매자와 판매자가 같을 수 없습니다.")
    expected = buyer_id if actor_role == "buyer" else seller_id
    _require(actor_id == expected, "해당 거래를 처리할 권한이 없습니다.", 403)
    # 구매확정과 같은 잠금 순서: 정렬된 사용자 → 상품 → 구매 → 판매등록 → 결제
    cursor.execute(
        """
        SELECT user_id, user_money
        FROM `user`
        WHERE user_id IN (%s, %s)
        ORDER BY user_id
        FOR UPDATE
        """, (buyer_id, seller_id),
    )
    users = {row["user_id"]: row for row in cursor.fetchall()}
    _require(buyer_id in users and seller_id in users, "거래 당사자 계정을 확인해주세요.")
    cursor.execute(
        """
        SELECT *
        FROM sell_product
        WHERE sell_product_code = %s
        FOR UPDATE
        """, (product_code,),
    )
    product = cursor.fetchone()
    _require(product is not None, "판매상품을 찾을 수 없습니다.", 404)
    cursor.execute(
        """
        SELECT *
        FROM purchase_item
        WHERE purchase_item_code = %s
        FOR UPDATE
        """, (purchase_code,),
    )
    purchase = cursor.fetchone()
    _require(purchase is not None, "구매 정보를 찾을 수 없습니다.", 404)
    _require(purchase["user_user_id"] == buyer_id and purchase["sell_product_sell_product_code"] == product_code,
             "구매 정보가 변경되었습니다.")
    cursor.execute(
        """
        SELECT *
        FROM post_item
        WHERE sell_product_sell_product_code = %s
        FOR UPDATE
        """, (product_code,),
    )
    posts = cursor.fetchall()
    _require(len(posts) == 1 and posts[0]["user_user_id"] == seller_id, "판매등록 정보가 변경되었습니다.")
    _require(posts[0]["post_item_complete_date"] is None, "구매확정 후에는 취소할 수 없습니다.")
    _require(product["sell_product_sell_status"] == "거래중", "거래 중인 상품만 취소할 수 있습니다.")
    cursor.execute(
        """
        SELECT *
        FROM cybermoney_pay
        WHERE purchase_item_purchase_item_code = %s
        FOR UPDATE
        """, (purchase_code,),
    )
    payments = cursor.fetchall()
    _require(len(payments) == 1 and payments[0]["cybermoney_pay_status"] == "결제완료", "결제 완료 상태를 확인해주세요.")
    return purchase, product, payments[0], users[buyer_id], seller_id


def _lock_cancel(cursor, purchase_code):
    cursor.execute(
        """
        SELECT *
        FROM purchase_cancel
        WHERE purchase_item_purchase_item_code = %s
        FOR UPDATE
        """, (purchase_code,),
    )
    return cursor.fetchone()


def _assert_unpaid_to_seller(cursor, pay_code):
    cursor.execute(
        """
        SELECT cybermoney_give_code
        FROM cybermoney_give
        WHERE cybermoney_pay_code = %s
        FOR UPDATE
        """, (pay_code,),
    )
    _require(cursor.fetchone() is None, "판매자 지급이 완료된 거래는 취소할 수 없습니다.")
    cursor.execute(
        """
        SELECT cybermoney_pay_cancel_code
        FROM cybermoney_pay_cancel
        WHERE cybermoney_pay_cybermoney_pay_code = %s
        FOR UPDATE
        """, (pay_code,),
    )
    _require(cursor.fetchone() is None, "이미 환불된 결제입니다.")


def create_purchase_cancel(db, request, buyer_id):
    try:
        db.begin()
        with db.cursor() as cursor:
            code = request.purchase_item_purchase_item_code
            purchase, product, payment, buyer, seller = _lock_trade(cursor, code, buyer_id, "buyer")
            _require(purchase["purchase_item_status"] == "거래중", "취소 요청 가능한 구매 상태가 아닙니다.")
            _require(_lock_cancel(cursor, code) is None, "구매 건당 취소 요청은 한 번만 가능합니다.")
            _assert_unpaid_to_seller(cursor, payment["cybermoney_pay_code"])
            now = _now()
            result = PurchaseCancelResponse(
                purchase_cancel_code=f"{code}_{now.strftime('%Y%m%d%H%M%S%f')}",
                purchase_item_purchase_item_code=code,
                user_user_id=buyer_id, seller_user_id=seller,
                purchase_cancel_date=now.isoformat(timespec="seconds"),
                purchase_cancel_reason=request.purchase_cancel_reason,
                purchase_cancel_status="요청중",
            )
            cursor.execute(
                """
                INSERT INTO purchase_cancel (
                    purchase_cancel_code, purchase_item_purchase_item_code,
                    user_user_id, purchase_cancel_date, purchase_cancel_reason, purchase_cancel_status
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """, (result.purchase_cancel_code, code, buyer_id, result.purchase_cancel_date,
                      result.purchase_cancel_reason, "요청중"),
            )
            cursor.execute(
                """
                UPDATE purchase_item
                SET purchase_item_status = %s
                WHERE purchase_item_code = %s AND purchase_item_status = %s
                """, ("취소요청", code, "거래중"),
            )
            _require(cursor.rowcount == 1, "구매 상태가 변경되었습니다.")
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 취소 요청이 존재합니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise
    return result


def process_purchase_cancel(db, cancel_code, actor_id, action, reason=None):
    _require(action in ("approve", "reject", "withdraw"), "잘못된 취소 처리입니다.", 422)
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute(
                """
                SELECT purchase_item_purchase_item_code
                FROM purchase_cancel
                WHERE purchase_cancel_code = %s
                """, (cancel_code,),
            )
            initial = cursor.fetchone()
            _require(initial is not None, "취소 요청을 찾을 수 없습니다.", 404)
            code = initial["purchase_item_purchase_item_code"]
            purchase, product, payment, buyer, seller = _lock_trade(
                cursor, code, actor_id, "buyer" if action == "withdraw" else "seller"
            )
            cancel = _lock_cancel(cursor, code)
            _require(cancel is not None and cancel["purchase_cancel_code"] == cancel_code, "취소 요청이 변경되었습니다.")
            _require(cancel["purchase_cancel_status"] == "요청중" and purchase["purchase_item_status"] == "취소요청",
                     "이미 처리된 요청이거나 취소 요청 상태가 아닙니다.")
            now = _now()
            timestamp = now.isoformat(timespec="seconds")
            status = {"approve": "승인", "reject": "거절", "withdraw": "철회"}[action]
            if action == "approve":
                pay_code = payment["cybermoney_pay_code"]
                _assert_unpaid_to_seller(cursor, pay_code)
                price = payment["cybermoney_pay_price"]
                _require(price is not None and price > 0, "환불 금액을 확인해주세요.")
                _require(buyer["user_money"] + price <= 2147483647, "환불 후 잔액이 최대 금액을 초과합니다.")
                cursor.execute(
                    """
                    UPDATE `user`
                    SET user_money = user_money + %s
                    WHERE user_id = %s
                    """, (price, buyer["user_id"]),
                )
                _require(cursor.rowcount == 1, "구매자 잔액을 변경할 수 없습니다.")
                cursor.execute(
                    """
                    INSERT INTO cybermoney_pay_cancel (
                        cybermoney_pay_cancel_code, user_user_id, cybermoney_pay_cancel_date,
                        cybermoney_pay_cancel_reason, cybermoney_pay_cybermoney_pay_code,
                        purchase_cancel_code, cybermoney_pay_cancel_price
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """, (f"{pay_code}_{now.strftime('%Y%m%d%H%M%S%f')}", buyer["user_id"], timestamp,
                          cancel["purchase_cancel_reason"], pay_code, cancel_code, price),
                )
                cursor.execute(
                    """
                    UPDATE cybermoney_pay
                    SET cybermoney_pay_status = %s
                    WHERE cybermoney_pay_code = %s AND cybermoney_pay_status = %s
                    """, ("결제취소", pay_code, "결제완료"),
                )
                _require(cursor.rowcount == 1, "결제 상태가 변경되었습니다.")
                cursor.execute(
                    """
                    UPDATE sell_product
                    SET sell_product_sell_status = %s
                    WHERE sell_product_code = %s AND sell_product_sell_status = %s
                    """, ("거래취소", product["sell_product_code"], "거래중"),
                )
                _require(cursor.rowcount == 1, "상품 상태가 변경되었습니다.")
            cursor.execute(
                """
                UPDATE purchase_item
                SET purchase_item_status = %s
                WHERE purchase_item_code = %s AND purchase_item_status = %s
                """, ("거래취소" if action == "approve" else "거래중", code, "취소요청"),
            )
            _require(cursor.rowcount == 1, "구매 상태가 변경되었습니다.")
            cursor.execute(
                """
                UPDATE purchase_cancel
                SET purchase_cancel_status = %s, responded_by_user_id = %s,
                    responded_at = %s, response_reason = %s
                WHERE purchase_cancel_code = %s AND purchase_cancel_status = %s
                """, (status, actor_id, timestamp, reason, cancel_code, "요청중"),
            )
            _require(cursor.rowcount == 1, "취소 요청 상태가 변경되었습니다.")
            result = PurchaseCancelResponse(**{
                **cancel, "seller_user_id": seller, "purchase_cancel_status": status,
                "responded_by_user_id": actor_id, "responded_at": timestamp, "response_reason": reason,
            })
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 환불 또는 취소 처리된 거래입니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise
    return result


def get_purchase_cancel(db, current, cancel_code=None):
    with db.cursor() as cursor:
        query = """
            SELECT pc.*, po.user_user_id AS seller_user_id
            FROM purchase_cancel pc
            JOIN purchase_item pi
                ON pi.purchase_item_code = pc.purchase_item_purchase_item_code
            JOIN post_item po
                ON po.sell_product_sell_product_code = pi.sell_product_sell_product_code
            WHERE 1 = 1
        """
        params = []
        if cancel_code is not None:
            query += "\n AND pc.purchase_cancel_code = %s"
            params.append(cancel_code)
        if current.role != "manager":
            query += "\n AND (pc.user_user_id = %s OR po.user_user_id = %s)"
            params.extend([current.account.user_id, current.account.user_id])
        query += "\n ORDER BY pc.purchase_cancel_date DESC, pc.purchase_cancel_code DESC"
        cursor.execute(query, tuple(params))
        rows = cursor.fetchall()
    if cancel_code is not None:
        _require(bool(rows), "취소 요청을 찾을 수 없거나 조회 권한이 없습니다.", 404)
        return PurchaseCancelResponse(**rows[0])
    return [PurchaseCancelResponse(**row) for row in rows]
