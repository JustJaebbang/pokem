from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.case import CaseCreate, CaseResponse


CASE_COLUMNS = "case_code, case_serial_no, case_price, case_stock"


def create_case(db, request: CaseCreate) -> CaseResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            # 시리얼별 순번 행을 확보한다. 같은 시리얼의 등록은 커밋까지 직렬화된다.
            cursor.execute(
                """INSERT INTO case_sequence (case_serial_no, last_seq) VALUES (%s, 0)
                ON DUPLICATE KEY UPDATE last_seq = last_seq""",
                (request.case_serial_no,),
            )
            cursor.execute(
                "SELECT last_seq FROM case_sequence WHERE case_serial_no = %s FOR UPDATE",
                (request.case_serial_no,),
            )
            seq = cursor.fetchone()["last_seq"] + 1
            case_code = f"{request.case_serial_no}{seq}"
            if seq > 2147483647 or len(case_code) > 45:
                raise HTTPException(status_code=409, detail="해당 시리얼의 케이스 코드 생성 한도를 초과했습니다.")
            cursor.execute(
                "UPDATE case_sequence SET last_seq = %s WHERE case_serial_no = %s",
                (seq, request.case_serial_no),
            )
            result = CaseResponse(case_code=case_code, **request.model_dump())
            # CASE는 SQL 키워드이므로 테이블 이름을 백틱으로 감싼다.
            cursor.execute(
                """INSERT INTO `case` (case_code, case_serial_no, case_price, case_stock)
                VALUES (%s, %s, %s, %s)""",
                (result.case_code, request.case_serial_no, request.case_price, request.case_stock),
            )
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 케이스 코드입니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_cases(db, limit: int = 20, offset: int = 0) -> list[CaseResponse]:
    # 코드 순으로 정렬해 페이지별 조회 결과의 순서를 유지한다.
    with db.cursor() as cursor:
        cursor.execute(
            f"SELECT {CASE_COLUMNS} FROM `case` ORDER BY case_code LIMIT %s OFFSET %s",
            (limit, offset),
        )
        rows = cursor.fetchall()
    return [CaseResponse(**row) for row in rows]


def get_case_code(db, case_code: str) -> CaseResponse | None:
    with db.cursor() as cursor:
        cursor.execute(f"SELECT {CASE_COLUMNS} FROM `case` WHERE case_code = %s", (case_code,))
        row = cursor.fetchone()
    return CaseResponse(**row) if row else None
