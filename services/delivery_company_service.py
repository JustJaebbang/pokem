from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.delivery_company import DeliveryCompanyCreate, DeliveryCompanyResponse


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
