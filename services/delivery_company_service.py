from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.delivery_company import DeliveryCompanyCreate, DeliveryCompanyResponse, DeliveryCompanyUpdate


def create_delivery_company(db, request: DeliveryCompanyCreate) -> DeliveryCompanyResponse:
    result = DeliveryCompanyResponse(**request.model_dump())
    try:
        with db.cursor() as cursor:
            cursor.execute(
                """INSERT INTO delivery_company (delivery_company_code, delivery_company_name)
                VALUES (%s, %s)""",
                (request.delivery_company_code, request.delivery_company_name),
            )
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 배송업체 코드입니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_delivery_companies(db, limit: int = 20, offset: int = 0) -> list[DeliveryCompanyResponse]:
    # 코드 기준으로 정렬하여 페이지별 조회 순서를 유지한다.
    with db.cursor() as cursor:
        cursor.execute(
            """SELECT delivery_company_code, delivery_company_name FROM delivery_company
            ORDER BY delivery_company_code LIMIT %s OFFSET %s""",
            (limit, offset),
        )
        rows = cursor.fetchall()
    return [DeliveryCompanyResponse(**row) for row in rows]


def get_delivery_company_code(db, delivery_company_code: str) -> DeliveryCompanyResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """SELECT delivery_company_code, delivery_company_name FROM delivery_company
            WHERE delivery_company_code = %s""",
            (delivery_company_code,),
        )
        row = cursor.fetchone()
    return DeliveryCompanyResponse(**row) if row else None


def update_delivery_company(db, code: str, request: DeliveryCompanyUpdate) -> DeliveryCompanyResponse:
    with db.cursor() as cursor:
        cursor.execute("UPDATE delivery_company SET delivery_company_name=%s WHERE delivery_company_code=%s",
                       (request.delivery_company_name, code))
        if cursor.rowcount != 1:
            db.rollback()
            raise HTTPException(status_code=404, detail="배송업체를 찾을 수 없습니다.")
    db.commit()
    return get_delivery_company_code(db, code)
