from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.product_company import ProductCompanyCreate, ProductCompanyResponse, ProductCompanyUpdate


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


def update_product_company(db, code: str, request: ProductCompanyUpdate) -> ProductCompanyResponse:
    with db.cursor() as cursor:
        cursor.execute("UPDATE product_company SET product_company_name=%s WHERE product_company_code=%s",
                       (request.product_company_name, code))
        if cursor.rowcount != 1:
            db.rollback()
            raise HTTPException(status_code=404, detail="제조업체를 찾을 수 없습니다.")
    db.commit()
    return get_product_company_code(db, code)
