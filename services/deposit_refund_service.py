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
                "SELECT user_user_id FROM pay WHERE pay_no = %s FOR UPDATE",
                (request.pay_pay_no,),
            )
            pay = cursor.fetchone()
            if pay is None:
                raise HTTPException(status_code=404, detail="해당 결제를 찾을 수 없습니다.")
            cursor.execute(
                "SELECT manager_id FROM manager WHERE manager_id = %s FOR UPDATE",
                (request.manager_manager_id,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="해당 매니저를 찾을 수 없습니다.")

            now = datetime.now(ZoneInfo("Asia/Seoul"))
            # 결제 번호와 반환일자(YYYYMMDD)를 연결한다. 같은 결제의 당일 중복 등록은 409로 처리한다.
            refund = DepositRefundResponse(
                deposit_refund_no=f"{request.pay_pay_no}{now:%Y%m%d}",
                deposit_refund_price=request.deposit_refund_price,
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


def get_deposit_refunds(db, limit: int = 20, offset: int = 0) -> list[DepositRefundResponse]:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT deposit_refund_no, deposit_refund_price, deposit_refund_date,
                   user_user_id, manager_manager_id, pay_pay_no
            FROM deposit_refund
            ORDER BY deposit_refund_date DESC, deposit_refund_no DESC
            LIMIT %s OFFSET %s
            """,
            (limit, offset),
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
