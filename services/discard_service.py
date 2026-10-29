from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.discard import DiscardCreate, DiscardResponse


DISCARD_COLUMNS = "manager_manager_id, discard_date, sell_product_sell_product_code"


def create_discard(db, request: DiscardCreate) -> DiscardResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute("SELECT manager_id FROM manager WHERE manager_id = %s FOR UPDATE", (request.manager_manager_id,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="등록 매니저를 찾을 수 없습니다.")
            cursor.execute(
                "SELECT sell_product_code FROM sell_product WHERE sell_product_code = %s FOR UPDATE",
                (request.sell_product_sell_product_code,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="상품을 찾을 수 없습니다.")

            result = DiscardResponse(
                **request.model_dump(),
                discard_date=datetime.now(timezone(timedelta(hours=9))).strftime("%Y-%m-%d %H:%M:%S"),
            )
            cursor.execute(
                """INSERT INTO discard (manager_manager_id, discard_date, sell_product_sell_product_code)
                VALUES (%s, %s, %s)""",
                (result.manager_manager_id, result.discard_date, result.sell_product_sell_product_code),
            )
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        # DB의 복합 기본키에 따라 같은 매니저·상품 조합은 한 번만 기록한다.
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="해당 매니저와 상품의 폐기 이력이 이미 있습니다.") from exc
        if exc.args[0] == 1452:
            raise HTTPException(status_code=400, detail="연결된 매니저 또는 상품을 확인해주세요.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_discards(db, limit: int = 20, offset: int = 0, manager_id: str | None = None) -> list[DiscardResponse]:
    owner_filter = "WHERE manager_manager_id = %s" if manager_id is not None else ""
    params = (manager_id, limit, offset) if manager_id is not None else (limit, offset)
    with db.cursor() as cursor:
        cursor.execute(
            f"""SELECT {DISCARD_COLUMNS} FROM discard {owner_filter}
            ORDER BY discard_date DESC, manager_manager_id, sell_product_sell_product_code
            LIMIT %s OFFSET %s""", params,
        )
        rows = cursor.fetchall()
    return [DiscardResponse(**row) for row in rows]


def get_discard(db, manager_id: str, sell_product_code: str) -> DiscardResponse | None:
    # 복합 기본키 두 컬럼으로 정확히 한 건을 조회한다.
    with db.cursor() as cursor:
        cursor.execute(
            f"""SELECT {DISCARD_COLUMNS} FROM discard
            WHERE manager_manager_id = %s AND sell_product_sell_product_code = %s""",
            (manager_id, sell_product_code),
        )
        row = cursor.fetchone()
    return DiscardResponse(**row) if row else None
