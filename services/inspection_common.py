from datetime import datetime, timedelta, timezone
from fastapi import HTTPException


def _now():
    return datetime.now(timezone(timedelta(hours=9))).isoformat(timespec="seconds")


def _require(condition, detail, status=409):
    if not condition:
        raise HTTPException(status_code=status, detail=detail)


def _inspect_row(c, inspect_code, lock=False):
    query = """
        SELECT i.*, ir.user_user_id
        FROM inspect i
        JOIN inspection_request ir ON ir.inspection_request_no = i.inspect_requested_no
        WHERE i.inspect_code = %s
    """
    if lock:
        query += "\n FOR UPDATE"
    c.execute(query, (inspect_code,))
    row=c.fetchone()
    _require(row is not None, "검수 상품을 찾을 수 없습니다.", 404)
    return row
