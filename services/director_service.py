from fastapi import HTTPException
from pymysql.err import IntegrityError

from security import hash_password, verify_password
from schemas.director import (
    DirectorCreate,
    DirectorDashboardResponse,
    DirectorLoginResponse,
    DirectorMetrics,
    DirectorResponse,
)
from services import case_service, manager_service, proposal_service


# SELECT에서도 비밀번호를 제외하여 불필요한 노출을 막는다.
DIRECTOR_COLUMNS = "director_id, director_name, director_phone, director_email, director_rank"


def login_director(db, login) -> DirectorLoginResponse:
    # 역할은 요청값이 아닌 실제 인증에 성공한 테이블에서 결정한다.
    with db.cursor() as cursor:
        cursor.execute(
            f"SELECT {DIRECTOR_COLUMNS}, director_password FROM director WHERE director_id = %s",
            (login.login_id,),
        )
        director = cursor.fetchone()
    if director is None or not verify_password(login.password, director["director_password"]):
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다.")
    return DirectorLoginResponse(account=DirectorResponse(**director))


def create_director(db, director: DirectorCreate) -> DirectorResponse:
    result = DirectorResponse(**director.model_dump(exclude={"director_password"}))
    try:
        password_hash = hash_password(director.director_password)
        with db.cursor() as cursor:
            cursor.execute(
                """INSERT INTO director (
                    director_id, director_password, director_name,
                    director_phone, director_email, director_rank
                ) VALUES (%s, %s, %s, %s, %s, %s)""",
                (director.director_id, password_hash, director.director_name,
                 director.director_phone, director.director_email, director.director_rank),
            )
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 director ID입니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_directors(db, limit: int = 20, offset: int = 0) -> list[DirectorResponse]:
    with db.cursor() as cursor:
        cursor.execute(
            f"SELECT {DIRECTOR_COLUMNS} FROM director ORDER BY director_id LIMIT %s OFFSET %s",
            (limit, offset),
        )
        rows = cursor.fetchall()
    return [DirectorResponse(**row) for row in rows]


def get_director_id(db, director_id: str) -> DirectorResponse | None:
    with db.cursor() as cursor:
        cursor.execute(f"SELECT {DIRECTOR_COLUMNS} FROM director WHERE director_id = %s", (director_id,))
        row = cursor.fetchone()
    return DirectorResponse(**row) if row else None


def get_director_dashboard(db) -> DirectorDashboardResponse:
    """총괄 화면에 필요한 수치와 결재 자료를 한 요청으로 일관되게 조회한다."""
    metric_queries = {
        "users": "SELECT COUNT(*) AS value FROM `user`",
        "managers": "SELECT COUNT(*) AS value FROM manager",
        "unassigned_requests": "SELECT COUNT(*) AS value FROM inspection_request WHERE manager_manager_id IS NULL",
        "inspections_in_progress": "SELECT COUNT(*) AS value FROM inspect WHERE inspect_status IN ('검수대기', '검수중')",
        "completed_inspections": "SELECT COUNT(*) AS value FROM inspect WHERE inspect_status = '검수완료'",
        "active_consignments": "SELECT COUNT(*) AS value FROM post_consign_item WHERE post_consign_item_complete_date IS NULL",
        "pending_proposals": "SELECT COUNT(*) AS value FROM proposal WHERE proposal_status = '대기'",
        "orders": "SELECT COUNT(*) AS value FROM `order`",
        "deliveries_in_progress": "SELECT COUNT(*) AS value FROM delivery WHERE delivery_status <> '배송완료'",
        "returns_in_progress": "SELECT COUNT(*) AS value FROM `return` WHERE return_status <> '반환완료'",
        "payments": "SELECT COUNT(*) AS value FROM pay",
        "refunds": "SELECT COUNT(*) AS value FROM deposit_refund",
        "case_stock": "SELECT COALESCE(SUM(case_stock), 0) AS value FROM `case`",
    }
    values = {}
    with db.cursor() as cursor:
        for name, query in metric_queries.items():
            cursor.execute(query)
            values[name] = int(cursor.fetchone()["value"])
    return DirectorDashboardResponse(
        metrics=DirectorMetrics(**values),
        proposals=proposal_service.get_proposals(db, 100, 0),
        managers=manager_service.get_manager(db),
        cases=case_service.get_cases(db, 100, 0),
    )
