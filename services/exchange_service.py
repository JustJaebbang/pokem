from datetime import datetime, timedelta, timezone

from fastapi import HTTPException

from schemas.exchange import ExchangeCreate, ExchangeResponse, ExchangeCreateResponse


# 실제 은행 송금은 연동되지 않음 -> 우리가 실제 계좌를 구현하지 않았으니까 
# 환전 요청 기록과 잔액 차감만 처리
# 같은 요청을 재전송하면 별도 환전으로 처리
def create_exchange(db, exchange: ExchangeCreate) -> ExchangeCreateResponse:
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
                (exchange.user_id,),
            )
            user = cursor.fetchone()
            if user is None:
                raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")

            balance = user["user_money"] - exchange.exchange_price
            if balance < 0:
                raise HTTPException(status_code=409, detail="사이버머니 잔액이 부족합니다.")

            now = datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds")
            cursor.execute(
                """
                INSERT INTO exchange (
                    user_id,
                    exchange_date,
                    exchange_account,
                    exchange_price
                )
                VALUES (%s, %s, %s, %s)
                """,
                (exchange.user_id, now, exchange.exchange_account, exchange.exchange_price),
            )
            exchange_seq = cursor.lastrowid
            cursor.execute(
                """
                UPDATE `user`
                SET user_money = user_money - %s
                WHERE user_id = %s
                    AND user_money >= %s
                """,
                (exchange.exchange_price, exchange.user_id, exchange.exchange_price),
            )
            if cursor.rowcount != 1:
                raise HTTPException(status_code=409, detail="잔액을 변경할 수 없습니다. 다시 확인해주세요.")
            result = ExchangeCreateResponse(
                message="포켐머니 환전이 완료되었습니다.",
                exchange_seq=exchange_seq,
                user_id=exchange.user_id,
                exchange_date=now,
                exchange_account=exchange.exchange_account,
                exchange_price=exchange.exchange_price,
                user_money=balance,
            )
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result


def get_exchange(db, user_id: str) -> list[ExchangeResponse]:
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
            FROM exchange
            WHERE user_id = %s
            ORDER BY exchange_seq DESC
            """,
            (user_id,),
        )
        rows = cursor.fetchall()
    return [ExchangeResponse(**row) for row in rows]


def get_exchange_seq(db, exchange_seq: int) -> ExchangeResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM exchange
            WHERE exchange_seq = %s
            """,
            (exchange_seq,),
        )
        row = cursor.fetchone()
    return ExchangeResponse(**row) if row else None
