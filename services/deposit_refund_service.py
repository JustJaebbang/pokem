from inspection_pricing import DEPOSIT_REFUND_UNIT_PRICE
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.deposit_refund import DepositRefundCreate, DepositRefundResponse


def create_deposit_refund(db, request: DepositRefundCreate) -> DepositRefundResponse:
    """환급 내역만 기록한다. 잔액 증감이나 실제 송금은 처리하지 않는다."""
    try:
        db.begin()
        with db.cursor() as cursor:
            # 요청자가 사용자 ID를 지정하지 않고, 연결된 결제의 사용자를 기록한다.
            cursor.execute(
                """SELECT user_user_id, pay_status, pay_price,
                          inspection_request_inspection_request_no
                   FROM pay WHERE pay_no = %s FOR UPDATE""",
                (request.pay_pay_no,),
            )
            pay = cursor.fetchone()
            if pay is None:
                raise HTTPException(status_code=404, detail="해당 결제를 찾을 수 없습니다.")
            if pay["pay_status"] != "결제완료":
                raise HTTPException(status_code=409, detail="결제완료된 검수비만 보증금을 환급할 수 있습니다.")
            cursor.execute(
                "SELECT manager_id FROM manager WHERE manager_id = %s FOR UPDATE",
                (request.manager_manager_id,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="해당 매니저를 찾을 수 없습니다.")

            # 결제 행 잠금을 모든 환급 요청이 공유해 동시 요청의 중복 환급을 막는다.
            cursor.execute(
                """SELECT inspect_code, inspect_status, inspect_grade
                   FROM inspect WHERE inspect_requested_no = %s FOR UPDATE""",
                (pay["inspection_request_inspection_request_no"],),
            )
            items = cursor.fetchall()
            eligible = sum(
                1 for item in items
                if item["inspect_status"] == "검수완료"
                and isinstance(item["inspect_grade"], str)
                and item["inspect_grade"].strip()
                and item["inspect_grade"].strip().upper() != "FAKE"
            )
            refundable_total = eligible * DEPOSIT_REFUND_UNIT_PRICE
            if refundable_total == 0:
                raise HTTPException(status_code=409, detail="환급 가능한 검수완료 카드가 없습니다.")
            if pay["pay_price"] is None or refundable_total > pay["pay_price"] or refundable_total > 2147483647:
                raise HTTPException(status_code=409, detail="검수 수량과 결제 금액을 확인해주세요.")
            cursor.execute(
                """SELECT deposit_refund_price FROM deposit_refund
                   WHERE pay_pay_no = %s FOR UPDATE""",
                (request.pay_pay_no,),
            )
            previous = cursor.fetchall()
            if any(row["deposit_refund_price"] is None or row["deposit_refund_price"] <= 0 for row in previous):
                raise HTTPException(status_code=409, detail="기존 환급 내역의 금액을 확인해주세요.")
            price = refundable_total - sum(row["deposit_refund_price"] for row in previous)
            if price <= 0:
                raise HTTPException(status_code=409, detail="새로 환급할 보증금이 없습니다.")

            now = datetime.now(ZoneInfo("Asia/Seoul"))
            # 분할 검수 완료 후 같은 날 추가 환급도 기록할 수 있도록 시각·마이크로초를 포함한다.
            refund = DepositRefundResponse(
                deposit_refund_no=f"{request.pay_pay_no}{now:%Y%m%d%H%M%S%f}",
                deposit_refund_price=price,
                deposit_refund_date=now.strftime("%Y-%m-%d %H:%M:%S"),
                user_user_id=pay["user_user_id"],
                manager_manager_id=request.manager_manager_id,
                pay_pay_no=request.pay_pay_no,
            )
            cursor.execute(
                """
                INSERT INTO deposit_refund (
                    deposit_refund_no, deposit_refund_price, deposit_refund_date,
                    user_user_id, manager_manager_id, pay_pay_no
                ) VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    refund.deposit_refund_no, refund.deposit_refund_price,
                    refund.deposit_refund_date, refund.user_user_id,
                    refund.manager_manager_id, refund.pay_pay_no,
                ),
            )
        db.commit()
        return refund
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1452:
            raise HTTPException(status_code=400, detail="연결된 결제, 사용자 또는 매니저가 없습니다.") from exc
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 존재하는 환급 내역입니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_deposit_refunds(db, limit: int = 20, offset: int = 0, user_id: str | None = None) -> list[DepositRefundResponse]:
    owner_filter = "WHERE user_user_id = %s" if user_id is not None else ""
    params = (user_id, limit, offset) if user_id is not None else (limit, offset)
    with db.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT deposit_refund_no, deposit_refund_price, deposit_refund_date,
                   user_user_id, manager_manager_id, pay_pay_no
            FROM deposit_refund {owner_filter}
            ORDER BY deposit_refund_date DESC, deposit_refund_no DESC
            LIMIT %s OFFSET %s
            """,
            params,
        )
        rows = cursor.fetchall()
    return [DepositRefundResponse(**row) for row in rows]


def get_deposit_refund(
    db, deposit_refund_no: str, user_user_id: str, pay_pay_no: str
) -> DepositRefundResponse | None:
    # 실제 DB의 기본키가 세 컬럼의 조합이므로 모두 사용해 한 건을 식별한다.
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT deposit_refund_no, deposit_refund_price, deposit_refund_date,
                   user_user_id, manager_manager_id, pay_pay_no
            FROM deposit_refund
            WHERE deposit_refund_no = %s AND user_user_id = %s AND pay_pay_no = %s
            """,
            (deposit_refund_no, user_user_id, pay_pay_no),
        )
        row = cursor.fetchone()
    return DepositRefundResponse(**row) if row else None
