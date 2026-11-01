from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.card_info import CardInfoCreate, CardInfoResponse


CARD_INFO_COLUMNS = """cardinfo_serial_code, cardinfo_category, cardinfo_brand,
    cardinfo_standard, cardinfo_last_sell_seq, cardinfo_last_inspect_seq"""


def create_card_info(db, request: CardInfoCreate) -> CardInfoResponse:
    """카탈로그를 추가하고 판매·검수 발급 순번은 항상 0에서 시작한다."""
    result = CardInfoResponse(**request.model_dump())
    try:
        with db.cursor() as cursor:
            cursor.execute(
                """INSERT INTO cardinfo (
                       cardinfo_serial_code, cardinfo_category,
                       cardinfo_brand, cardinfo_standard,
                       cardinfo_last_sell_seq, cardinfo_last_inspect_seq
                   ) VALUES (%s, %s, %s, %s, 0, 0)""",
                (
                    request.cardinfo_serial_code,
                    request.cardinfo_category,
                    request.cardinfo_brand,
                    request.cardinfo_standard,
                ),
            )
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 카드 일련코드입니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_card_infos(db, limit: int = 20, offset: int = 0) -> list[CardInfoResponse]:
    with db.cursor() as cursor:
        cursor.execute(
            f"SELECT {CARD_INFO_COLUMNS} FROM cardinfo "
            "ORDER BY cardinfo_serial_code LIMIT %s OFFSET %s",
            (limit, offset),
        )
        rows = cursor.fetchall()
    return [CardInfoResponse(**row) for row in rows]


def get_card_info(db, serial_code: str) -> CardInfoResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            f"SELECT {CARD_INFO_COLUMNS} FROM cardinfo WHERE cardinfo_serial_code = %s",
            (serial_code,),
        )
        row = cursor.fetchone()
    return CardInfoResponse(**row) if row else None
