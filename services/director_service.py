import csv
from datetime import datetime, timedelta
from io import BytesIO, StringIO
from zoneinfo import ZoneInfo

from fastapi import HTTPException
from openpyxl import Workbook
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
from services import (
    case_service,
    director_settings_service,
    manager_service,
    proposal_service,
)


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


def _validate_date_range(date_from: str | None, date_to: str | None) -> None:
    # YYYY-MM-DD 문자열은 사전식 정렬과 날짜 순서가 같으므로 DATETIME 변환이 필요 없다.
    if date_from and date_to and date_from > date_to:
        raise HTTPException(status_code=422, detail="시작일은 종료일보다 늦을 수 없습니다.")


def _filters(
    *,
    date_column: str | None = None,
    manager_column: str | None = None,
    status_column: str | None = None,
    date_from: str | None = None,
    date_to: str | None = None,
    manager_id: str | None = None,
    inspect_status: str | None = None,
) -> tuple[list[str], list[object]]:
    clauses: list[str] = []
    params: list[object] = []
    if date_column and date_from:
        clauses.append(f"SUBSTRING(REPLACE({date_column}, 'T', ' '), 1, 10) >= %s")
        params.append(date_from)
    if date_column and date_to:
        clauses.append(f"SUBSTRING(REPLACE({date_column}, 'T', ' '), 1, 10) <= %s")
        params.append(date_to)
    if manager_column and manager_id:
        clauses.append(f"{manager_column} = %s")
        params.append(manager_id)
    if status_column and inspect_status:
        clauses.append(f"{status_column} = %s")
        params.append(inspect_status)
    return clauses, params


def get_director_dashboard(
    db,
    *,
    date_from: str | None = None,
    date_to: str | None = None,
    manager_id: str | None = None,
    inspect_status: str | None = None,
) -> DirectorDashboardResponse:
    """총괄 화면에 필요한 수치, 결재 자료, 필터 통계를 함께 조회한다."""
    _validate_date_range(date_from, date_to)
    settings = director_settings_service.get_settings(db)
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
    statistics = _get_operations_statistics(
        db,
        values,
        settings,
        date_from=date_from,
        date_to=date_to,
        manager_id=manager_id,
        inspect_status=inspect_status,
    )
    return DirectorDashboardResponse(
        metrics=DirectorMetrics(**values),
        proposals=proposal_service.get_proposals(db, 100, 0),
        managers=manager_service.get_manager(db),
        cases=case_service.get_cases(db, 100, 0),
        withdrawals=withdrawals,
        statistics=statistics,
        settings=settings,
    )


def _get_operations_statistics(
    db,
    metrics: dict[str, int],
    settings,
    *,
    date_from: str | None,
    date_to: str | None,
    manager_id: str | None,
    inspect_status: str | None,
) -> DirectorOperationsStatistics:
    """결재 통계를 제외한 검수·재고·물류·탈퇴 운영 지표를 계산한다."""
    inspect_filters, inspect_params = _filters(
        date_column="i.inspect_date",
        manager_column="i.manager_manager_id",
        status_column="i.inspect_status",
        date_from=date_from,
        date_to=date_to,
        manager_id=manager_id,
        inspect_status=inspect_status,
    )
    inspect_where = " AND " + " AND ".join(inspect_filters) if inspect_filters else ""
    request_filters, request_params = _filters(
        date_column="ir.inspection_request_date",
        manager_column="ir.manager_manager_id",
        date_from=date_from,
        date_to=date_to,
        manager_id=manager_id,
    )
    request_where = " AND " + " AND ".join(request_filters) if request_filters else ""
    order_filters, order_params = _filters(
        date_column="o.order_date",
        manager_column="o.manager_manager_id",
        date_from=date_from,
        date_to=date_to,
        manager_id=manager_id,
    )
    order_where = "WHERE " + " AND ".join(order_filters) if order_filters else ""
    delivery_filters, delivery_params = _filters(
        date_column="d.delivery_date",
        manager_column="d.manager_manager_id",
        date_from=date_from,
        date_to=date_to,
        manager_id=manager_id,
    )
    return_filters, return_params = _filters(
        manager_column="r.manager_manager_id", manager_id=manager_id
    )
    quit_filters, quit_params = _filters(
        date_column="q.quit_date", date_from=date_from, date_to=date_to
    )

    with db.cursor() as cursor:
        cursor.execute(
            "SELECT COUNT(*) AS value FROM inspection_request ir "
            "WHERE ir.manager_manager_id IS NULL" + request_where,
            tuple(request_params),
        )
        filtered_unassigned = int(cursor.fetchone()["value"])
        cursor.execute(
            """SELECT
                   SUM(i.inspect_status = '검수대기') AS waiting,
                   SUM(i.inspect_status = '검수중') AS in_progress,
                   SUM(i.inspect_status = '검수완료') AS completed
               FROM inspect i WHERE 1 = 1""" + inspect_where,
            tuple(inspect_params),
        )
        pipeline_row = cursor.fetchone()
        pipeline = DirectorInspectionPipeline(
            unassigned_requests=filtered_unassigned,
            waiting=int(pipeline_row["waiting"] or 0),
            in_progress=int(pipeline_row["in_progress"] or 0),
            completed=int(pipeline_row["completed"] or 0),
        )

        cursor.execute(
            """SELECT m.manager_id, m.manager_name,
                      COUNT(i.inspect_code) AS total,
                      COALESCE(SUM(i.inspect_status = '검수완료'), 0) AS completed,
                      COALESCE(SUM(i.inspect_status IN ('검수대기', '검수중')), 0) AS active
               FROM manager m
               LEFT JOIN inspect i ON i.manager_manager_id = m.manager_id"""
            + inspect_where
            + """
               GROUP BY m.manager_id, m.manager_name
               ORDER BY completed DESC, total DESC, m.manager_id""",
            tuple(inspect_params),
        )
        manager_inspections = [
            DirectorManagerInspectionStat(**row) for row in cursor.fetchall()
        ]

        cursor.execute(
            """SELECT case_code, case_stock, %s AS threshold
               FROM `case` WHERE case_stock <= %s
               ORDER BY case_stock, case_code""",
            (settings.low_stock_threshold, settings.low_stock_threshold),
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
               """ + order_where + """
               GROUP BY o.order_no, o.order_date, o.case_case_code, o.order_amount
               HAVING outstanding_amount > 0
               ORDER BY o.order_date, o.order_no""",
            tuple(order_params),
        )
        outstanding_orders = [
            DirectorOutstandingOrder(**row) for row in cursor.fetchall()
        ]

        # 기준 시각도 문자열로 만들어 VARCHAR 날짜 컬럼과 정규화된 문자열끼리 비교한다.
        delay_cutoff = (
            datetime.now(ZoneInfo("Asia/Seoul"))
            - timedelta(days=settings.delivery_delay_days)
        ).strftime("%Y-%m-%d %H:%M:%S")
        delayed_where = [
            "d.delivery_status <> '배송완료'",
            "REPLACE(SUBSTRING(d.delivery_date, 1, 19), 'T', ' ') < %s",
            *delivery_filters,
        ]
        delayed_params = [delay_cutoff, *delivery_params]
        cursor.execute(
            "SELECT COUNT(*) AS value FROM delivery d WHERE "
            + " AND ".join(delayed_where),
            tuple(delayed_params),
        )
        delayed_deliveries = int(cursor.fetchone()["value"])
        cursor.execute(
            """SELECT delivery_no, delivery_date, delivery_status,
                      manager_manager_id AS manager_id,
                      delivery_company_delivery_company_code AS company_code
               FROM delivery d WHERE """
            + " AND ".join(delayed_where)
            + " ORDER BY d.delivery_date, d.delivery_no LIMIT 100",
            tuple(delayed_params),
        )
        delayed_delivery_items = [
            DirectorDelayedDelivery(**row) for row in cursor.fetchall()
        ]

        cursor.execute(
            """SELECT COUNT(*) AS value FROM `return` r
               WHERE r.return_status <> '반환완료'"""
            + (" AND " + " AND ".join(return_filters) if return_filters else "")
            + """
                 AND NOT EXISTS (
                     SELECT 1 FROM delivery d WHERE d.return_return_no = r.return_no
                 )""",
            tuple(return_params),
        )
        returns_without_delivery = int(cursor.fetchone()["value"])
        cursor.execute(
            """SELECT r.return_no, r.return_status, r.user_user_id AS user_id,
                      r.manager_manager_id AS manager_id
               FROM `return` r
               WHERE r.return_status <> '반환완료'"""
            + (" AND " + " AND ".join(return_filters) if return_filters else "")
            + """
                 AND NOT EXISTS (
                     SELECT 1 FROM delivery d WHERE d.return_return_no = r.return_no
                 )
               ORDER BY r.return_no
               LIMIT 100""",
            tuple(return_params),
        )
        return_without_delivery_items = [
            DirectorReturnWithoutDelivery(**row) for row in cursor.fetchall()
        ]

        cursor.execute(
            "SELECT q.quit_type, COUNT(*) AS count FROM `quit` q"
            + (" WHERE " + " AND ".join(quit_filters) if quit_filters else "")
            + " GROUP BY q.quit_type ORDER BY count DESC, q.quit_type",
            tuple(quit_params),
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


STATISTICS_KINDS = {
    "inspections",
    "low_stock",
    "outstanding_orders",
    "delayed_deliveries",
    "returns_without_delivery",
    "withdrawals",
    "managers",
}


def _statistics_query(
    kind: str,
    settings,
    *,
    date_from: str | None,
    date_to: str | None,
    manager_id: str | None,
    inspect_status: str | None,
) -> tuple[str, list[object]]:
    if kind not in STATISTICS_KINDS:
        raise HTTPException(status_code=404, detail="지원하지 않는 통계 종류입니다.")

    if kind == "inspections":
        filters, params = _filters(
            date_column="i.inspect_date", manager_column="i.manager_manager_id",
            status_column="i.inspect_status", date_from=date_from, date_to=date_to,
            manager_id=manager_id, inspect_status=inspect_status,
        )
        query = """SELECT i.inspect_code, i.inspect_date, i.inspect_status,
                          i.inspect_grade, i.inspect_grade_reason,
                          i.inspect_requested_no, i.manager_manager_id AS manager_id
                   FROM inspect i"""
        order = " ORDER BY i.inspect_date DESC, i.inspect_code"
    elif kind == "low_stock":
        filters, params = ["c.case_stock <= %s"], [settings.low_stock_threshold]
        query = "SELECT c.case_code, c.case_stock, %s AS threshold FROM `case` c"
        params.insert(0, settings.low_stock_threshold)
        order = " ORDER BY c.case_stock, c.case_code"
    elif kind == "outstanding_orders":
        filters, params = _filters(
            date_column="o.order_date", manager_column="o.manager_manager_id",
            date_from=date_from, date_to=date_to, manager_id=manager_id,
        )
        query = """SELECT o.order_no, o.order_date, o.case_case_code AS case_code,
                          o.manager_manager_id AS manager_id,
                          COALESCE(o.order_amount, 0) AS order_amount,
                          COALESCE(SUM(r.receive_amount), 0) AS received_amount,
                          GREATEST(COALESCE(o.order_amount, 0) -
                              COALESCE(SUM(r.receive_amount), 0), 0) AS outstanding_amount
                   FROM `order` o LEFT JOIN receive r ON r.order_order_no = o.order_no"""
        order = " GROUP BY o.order_no, o.order_date, o.case_case_code, o.manager_manager_id, o.order_amount HAVING outstanding_amount > 0 ORDER BY o.order_date, o.order_no"
    elif kind == "delayed_deliveries":
        cutoff = (datetime.now(ZoneInfo("Asia/Seoul")) - timedelta(
            days=settings.delivery_delay_days
        )).strftime("%Y-%m-%d %H:%M:%S")
        filters, params = _filters(
            date_column="d.delivery_date", manager_column="d.manager_manager_id",
            date_from=date_from, date_to=date_to, manager_id=manager_id,
        )
        filters = ["d.delivery_status <> '배송완료'", "REPLACE(SUBSTRING(d.delivery_date, 1, 19), 'T', ' ') < %s", *filters]
        params = [cutoff, *params]
        query = """SELECT d.delivery_no, d.delivery_date, d.delivery_status,
                          d.manager_manager_id AS manager_id,
                          d.delivery_company_delivery_company_code AS company_code
                   FROM delivery d"""
        order = " ORDER BY d.delivery_date, d.delivery_no"
    elif kind == "returns_without_delivery":
        filters, params = _filters(manager_column="r.manager_manager_id", manager_id=manager_id)
        filters = ["r.return_status <> '반환완료'", "NOT EXISTS (SELECT 1 FROM delivery d WHERE d.return_return_no = r.return_no)", *filters]
        query = """SELECT r.return_no, r.return_status, r.user_user_id AS user_id,
                          r.manager_manager_id AS manager_id FROM `return` r"""
        order = " ORDER BY r.return_no"
    elif kind == "withdrawals":
        filters, params = _filters(
            date_column="q.quit_date", date_from=date_from, date_to=date_to
        )
        query = """SELECT q.user_user_id AS user_id, u.user_nickname,
                          q.quit_date, q.quit_type, q.quit_reason
                   FROM `quit` q LEFT JOIN `user` u ON u.user_id = q.user_user_id"""
        order = " ORDER BY q.quit_date DESC, q.user_user_id"
    else:
        filters, params = [], []
        query = """SELECT m.manager_id, m.manager_name, m.manager_phone,
                          m.manager_email, m.manager_dept, m.manager_active,
                          m.manager_updated_at FROM manager m"""
        order = " ORDER BY m.manager_active DESC, m.manager_id"
    where = " WHERE " + " AND ".join(filters) if filters else ""
    return query + where + order, params


def _fetch_statistics(
    db, kind: str, *, limit: int | None, offset: int = 0, **filters
) -> tuple[int, list[dict]]:
    _validate_date_range(filters.get("date_from"), filters.get("date_to"))
    settings = director_settings_service.get_settings(db)
    query, params = _statistics_query(kind, settings, **filters)
    with db.cursor() as cursor:
        cursor.execute(f"SELECT COUNT(*) AS value FROM ({query}) statistic_rows", tuple(params))
        total = int(cursor.fetchone()["value"])
        if limit is None:
            cursor.execute(query, tuple(params))
        else:
            cursor.execute(query + " LIMIT %s OFFSET %s", tuple(params) + (limit, offset))
        rows = cursor.fetchall()
    return total, rows


def get_statistics_page(db, kind: str, limit: int, offset: int, **filters):
    total, rows = _fetch_statistics(db, kind, limit=limit, offset=offset, **filters)
    return {"kind": kind, "total": total, "limit": limit, "offset": offset, "items": rows}


def export_statistics(db, kind: str, format: str, **filters):
    _, rows = _fetch_statistics(db, kind, limit=None, **filters)
    columns = list(rows[0].keys()) if rows else []
    stamp = datetime.now(ZoneInfo("Asia/Seoul")).strftime("%Y%m%d_%H%M%S")
    if format == "csv":
        output = StringIO()
        output.write("\ufeff")
        writer = csv.DictWriter(output, fieldnames=columns)
        if columns:
            writer.writeheader()
            writer.writerows(rows)
        return output.getvalue().encode("utf-8"), "text/csv; charset=utf-8", f"director_{kind}_{stamp}.csv"

    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "statistics"
    if columns:
        sheet.append(columns)
        for row in rows:
            sheet.append([row.get(column) for column in columns])
    output_bytes = BytesIO()
    workbook.save(output_bytes)
    return output_bytes.getvalue(), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", f"director_{kind}_{stamp}.xlsx"
