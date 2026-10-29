from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.product_company import ProductCompanyCreate, ProductCompanyResponse


def create_product_company(db, request: ProductCompanyCreate) -> ProductCompanyResponse:
    result = ProductCompanyResponse(**request.model_dump())
    try:
        with db.cursor() as cursor:
            cursor.execute(
                """INSERT INTO product_company (product_company_code, product_company_name)
                VALUES (%s, %s)""",
                (request.product_company_code, request.product_company_name),
            )
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 제조업체 코드입니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_product_companies(db, limit: int = 20, offset: int = 0) -> list[ProductCompanyResponse]:
    # 코드 기준으로 정렬하여 페이지별 조회 순서를 유지한다.
    with db.cursor() as cursor:
        cursor.execute(
            """SELECT product_company_code, product_company_name FROM product_company
            ORDER BY product_company_code LIMIT %s OFFSET %s""",
            (limit, offset),
        )
        rows = cursor.fetchall()
    return [ProductCompanyResponse(**row) for row in rows]


def get_product_company_code(db, product_company_code: str) -> ProductCompanyResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """SELECT product_company_code, product_company_name FROM product_company
            WHERE product_company_code = %s""",
            (product_company_code,),
        )
        row = cursor.fetchone()
    return ProductCompanyResponse(**row) if row else None
