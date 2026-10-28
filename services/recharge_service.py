from datetime import datetime, timedelta, timezone

from fastapi import HTTPException

from schemas.recharge import RechargeCreate, RechargeResponse, RechargeCreateResponse


# 입금·결제 승인 검증은 아직 연동되지 않았습니다.
# 같은 요청을 재전송하면 별도 충전으로 처리됩니다.
def create_recharge(db, recharge: RechargeCreate) -> RechargeCreateResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute(
                """
                SELECT user_money
                FROM `user`
                WHERE user_id = %s
                FOR UPDATE
                """,
                (recharge.user_user_id,),
            )
            user = cursor.fetchone()
            if user is None:
                raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

            balance = user["user_money"] + recharge.recharge_price
            if balance > 2147483647:
                raise HTTPException(status_code=409, detail="충전 후 잔액이 저장 가능한 최대 금액을 초과합니다.")

            now = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds")
            cursor.execute(
                """
                INSERT INTO recharge (
                    user_user_id,
                    recharge_date,
                    recharge_account,
                    recharge_price
                )
                VALUES (%s, %s, %s, %s)
                """,
                (recharge.user_user_id, now, recharge.recharge_account, recharge.recharge_price),
            )
            recharge_seq = cursor.lastrowid
            cursor.execute(
                """
                UPDATE `user`
                SET user_money = user_money + %s
                WHERE user_id = %s
                """,
                (recharge.recharge_price, recharge.user_user_id),
            )
            result = RechargeCreateResponse(
                message="사이버머니 충전이 완료되었습니다.",
                recharge_seq=recharge_seq,
                user_user_id=recharge.user_user_id,
                recharge_date=now,
                recharge_account=recharge.recharge_account,
                recharge_price=recharge.recharge_price,
                user_money=balance,
            )
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result


def get_recharge(db, user_id: str) -> list[RechargeResponse]:
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
            FROM recharge
            WHERE user_user_id = %s
            ORDER BY recharge_seq DESC
            """,
            (user_id,),
        )
        rows = cursor.fetchall()
    return [RechargeResponse(**row) for row in rows]


def get_recharge_seq(db, recharge_seq: int) -> RechargeResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM recharge
            WHERE recharge_seq = %s
            """,
            (recharge_seq,),
        )
        row = cursor.fetchone()
    return RechargeResponse(**row) if row else None
