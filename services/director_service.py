from fastapi import HTTPException
from pymysql.err import IntegrityError

from security import hash_password, verify_password
from schemas.director import (
    DirectorCreate,
    DirectorDashboardResponse,
    DirectorDelayedDelivery,
    DirectorLoginResponse,
    DirectorInspectionPipeline,
    DirectorLowStockCase,
    DirectorManagerInspectionStat,
    DirectorMetrics,
    DirectorOperationsStatistics,
    DirectorOutstandingOrder,
    DirectorQuitTypeStat,
    DirectorReturnWithoutDelivery,
    DirectorResponse,
    DirectorWithdrawalResponse,
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
        "withdrawn_users": "SELECT COUNT(*) AS value FROM `quit`",
    }
    values = {}
    with db.cursor() as cursor:
        for name, query in metric_queries.items():
            cursor.execute(query)
            values[name] = int(cursor.fetchone()["value"])
    with db.cursor() as cursor:
        cursor.execute(
            """SELECT q.user_user_id AS user_id, u.user_nickname,
                      q.quit_date, q.quit_type, q.quit_reason
               FROM `quit` q
               LEFT JOIN `user` u ON u.user_id = q.user_user_id
               ORDER BY q.quit_date DESC, q.user_user_id
               LIMIT 100"""
        )
        withdrawals = [DirectorWithdrawalResponse(**row) for row in cursor.fetchall()]
    statistics = _get_operations_statistics(db, values)
    return DirectorDashboardResponse(
        metrics=DirectorMetrics(**values),
        proposals=proposal_service.get_proposals(db, 100, 0),
        managers=manager_service.get_manager(db),
        cases=case_service.get_cases(db, 100, 0),
        withdrawals=withdrawals,
        statistics=statistics,
    )


def _get_operations_statistics(db, metrics: dict[str, int]) -> DirectorOperationsStatistics:
    """결재 통계를 제외한 검수·재고·물류·탈퇴 운영 지표를 계산한다."""
    with db.cursor() as cursor:
        cursor.execute(
            """SELECT
                   SUM(inspect_status = '검수대기') AS waiting,
                   SUM(inspect_status = '검수중') AS in_progress
               FROM inspect"""
        )
        pipeline_row = cursor.fetchone()
        pipeline = DirectorInspectionPipeline(
            unassigned_requests=metrics["unassigned_requests"],
            waiting=int(pipeline_row["waiting"] or 0),
            in_progress=int(pipeline_row["in_progress"] or 0),
            completed=metrics["completed_inspections"],
        )

        cursor.execute(
            """SELECT m.manager_id, m.manager_name,
                      COUNT(i.inspect_code) AS total,
                      COALESCE(SUM(i.inspect_status = '검수완료'), 0) AS completed,
                      COALESCE(SUM(i.inspect_status IN ('검수대기', '검수중')), 0) AS active
               FROM manager m
               LEFT JOIN inspect i ON i.manager_manager_id = m.manager_id
               GROUP BY m.manager_id, m.manager_name
               ORDER BY completed DESC, total DESC, m.manager_id"""
        )
        manager_inspections = [
            DirectorManagerInspectionStat(**row) for row in cursor.fetchall()
        ]

        # 운영 초기 기준은 10개이며 향후 설정 테이블로 분리할 수 있다.
        cursor.execute(
            """SELECT case_code, case_stock, 10 AS threshold
               FROM `case` WHERE case_stock <= 10
               ORDER BY case_stock, case_code"""
        )
        low_stock_cases = [DirectorLowStockCase(**row) for row in cursor.fetchall()]

        cursor.execute(
            """SELECT o.order_no, o.order_date, o.case_case_code AS case_code,
                      COALESCE(o.order_amount, 0) AS order_amount,
                      COALESCE(SUM(r.receive_amount), 0) AS received_amount,
                      GREATEST(COALESCE(o.order_amount, 0) - COALESCE(SUM(r.receive_amount), 0), 0)
                          AS outstanding_amount
               FROM `order` o
               LEFT JOIN receive r ON r.order_order_no = o.order_no
               GROUP BY o.order_no, o.order_date, o.case_case_code, o.order_amount
               HAVING outstanding_amount > 0
               ORDER BY o.order_date, o.order_no"""
        )
        outstanding_orders = [
            DirectorOutstandingOrder(**row) for row in cursor.fetchall()
        ]

        # delivery_date가 문자열이므로 ISO/일반 날짜의 앞 19자만 정규화해 비교한다.
        cursor.execute(
            """SELECT COUNT(*) AS value FROM delivery
               WHERE delivery_status <> '배송완료'
                 AND STR_TO_DATE(REPLACE(SUBSTRING(delivery_date, 1, 19), 'T', ' '),
                                 '%Y-%m-%d %H:%i:%s') < NOW() - INTERVAL 3 DAY"""
        )
        delayed_deliveries = int(cursor.fetchone()["value"])
        cursor.execute(
            """SELECT delivery_no, delivery_date, delivery_status,
                      manager_manager_id AS manager_id,
                      delivery_company_delivery_company_code AS company_code
               FROM delivery
               WHERE delivery_status <> '배송완료'
                 AND STR_TO_DATE(REPLACE(SUBSTRING(delivery_date, 1, 19), 'T', ' '),
                                 '%Y-%m-%d %H:%i:%s') < NOW() - INTERVAL 3 DAY
               ORDER BY delivery_date, delivery_no
               LIMIT 100"""
        )
        delayed_delivery_items = [
            DirectorDelayedDelivery(**row) for row in cursor.fetchall()
        ]

        cursor.execute(
            """SELECT COUNT(*) AS value FROM `return` r
               WHERE r.return_status <> '반환완료'
                 AND NOT EXISTS (
                     SELECT 1 FROM delivery d WHERE d.return_return_no = r.return_no
                 )"""
        )
        returns_without_delivery = int(cursor.fetchone()["value"])
        cursor.execute(
            """SELECT r.return_no, r.return_status, r.user_user_id AS user_id,
                      r.manager_manager_id AS manager_id
               FROM `return` r
               WHERE r.return_status <> '반환완료'
                 AND NOT EXISTS (
                     SELECT 1 FROM delivery d WHERE d.return_return_no = r.return_no
                 )
               ORDER BY r.return_no
               LIMIT 100"""
        )
        return_without_delivery_items = [
            DirectorReturnWithoutDelivery(**row) for row in cursor.fetchall()
        ]

        cursor.execute(
            """SELECT quit_type, COUNT(*) AS count FROM `quit`
               GROUP BY quit_type ORDER BY count DESC, quit_type"""
        )
        quit_types = [DirectorQuitTypeStat(**row) for row in cursor.fetchall()]

    return DirectorOperationsStatistics(
        pipeline=pipeline,
        manager_inspections=manager_inspections,
        low_stock_cases=low_stock_cases,
        outstanding_orders=outstanding_orders,
        delayed_deliveries=delayed_deliveries,
        returns_without_delivery=returns_without_delivery,
        quit_types=quit_types,
        delayed_delivery_items=delayed_delivery_items,
        return_without_delivery_items=return_without_delivery_items,
    )
