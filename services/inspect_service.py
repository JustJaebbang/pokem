from schemas.inspect import InspectResponse
from services.inspection_common import _now, _require, _inspect_row


def create_inspect(db, item, manager_id):
    try:
        db.begin()
        with db.cursor() as c:
            c.execute(
                """
                SELECT *
                FROM inspection_request
                WHERE inspection_request_no = %s
                FOR UPDATE
                """, (item.inspect_requested_no,),
            )
            request=c.fetchone()
            _require(request is not None, "검수신청을 찾을 수 없습니다.", 404)
            c.execute(
                """
                SELECT COUNT(*) AS item_count
                FROM inspect
                WHERE inspect_requested_no = %s
                """, (item.inspect_requested_no,),
            )
            amount=request["inspection_request_amount"]
            _require(amount is not None and c.fetchone()["item_count"] < amount, "신청한 상품 개수를 초과할 수 없습니다.")
            c.execute(
                """
                SELECT cardinfo_last_inspect_seq
                FROM cardinfo
                WHERE cardinfo_serial_code = %s
                FOR UPDATE
                """, (item.inspect_serial_code,),
            )
            catalog=c.fetchone()
            _require(catalog is not None, "카탈로그 상품을 찾을 수 없습니다.", 404)
            seq=catalog["cardinfo_last_inspect_seq"]+1
            _require(seq <= 18446744073709551615, "검수 순번의 최대값을 초과했습니다.")
            c.execute(
                """
                UPDATE cardinfo
                SET cardinfo_last_inspect_seq = %s
                WHERE cardinfo_serial_code = %s
                """, (seq, item.inspect_serial_code),
            )
            code=f"INS_{item.inspect_serial_code}-{seq}"
            c.execute(
                """
                INSERT INTO inspect (
                    inspect_code, inspect_serial_code, seq, inspect_requested_no,
                    inspect_status, manager_manager_id
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """, (code, item.inspect_serial_code, seq, item.inspect_requested_no, "검수대기", manager_id),
            )
            result=InspectResponse(**_inspect_row(c, code))
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result


def get_inspects(db, current, inspect_code=None, request_no=None):
    query = """
        SELECT i.*, ir.user_user_id
        FROM inspect i
        JOIN inspection_request ir ON ir.inspection_request_no = i.inspect_requested_no
        WHERE 1 = 1
    """
    params=[]
    if inspect_code is not None:
        query += "\n AND i.inspect_code = %s"
        params.append(inspect_code)
    if request_no is not None:
        query += "\n AND i.inspect_requested_no = %s"
        params.append(request_no)
    if current.role != "manager":
        query += "\n AND ir.user_user_id = %s"
        params.append(current.account.user_id)
    query += "\n ORDER BY i.inspect_requested_no, i.inspect_code"
    with db.cursor() as c:
        c.execute(query, tuple(params))
        rows=c.fetchall()
    if inspect_code is not None:
        _require(bool(rows), "검수 상품을 찾을 수 없거나 조회 권한이 없습니다.", 404)
        return InspectResponse(**rows[0])
    return [InspectResponse(**r) for r in rows]


def transition_inspect(db, code, manager_id, complete=None):
    try:
        db.begin()
        with db.cursor() as c:
            row=_inspect_row(c, code, lock=True)
            expected="검수중" if complete else "검수대기"
            _require(row["inspect_status"] == expected, "검수 상태를 확인해주세요.")
            if complete:
                c.execute(
                    """
                    UPDATE inspect
                    SET inspect_status = %s, inspect_date = %s, inspect_grade = %s,
                        inspect_grade_reason = %s, inspect_user_choice = %s, manager_manager_id = %s
                    WHERE inspect_code = %s AND inspect_status = %s
                    """, ("검수완료", _now(), complete.inspect_grade, complete.inspect_grade_reason,
                          "의사확인대기", manager_id, code, expected),
                )
            else:
                c.execute(
                    """
                    UPDATE inspect
                    SET inspect_status = %s, manager_manager_id = %s
                    WHERE inspect_code = %s AND inspect_status = %s
                    """, ("검수중", manager_id, code, expected),
                )
            _require(c.rowcount == 1, "검수 상태가 변경되었습니다.")
            result=InspectResponse(**_inspect_row(c, code))
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result


def choose_inspect(db, code, choice, user_id):
    try:
        db.begin()
        with db.cursor() as c:
            row=_inspect_row(c, code, lock=True)
            _require(row["user_user_id"] == user_id, "신청자만 선택할 수 있습니다.", 403)
            _require(row["inspect_status"] == "검수완료", "검수가 완료된 후 선택해주세요.")
            if row["inspect_user_choice"] != choice.inspect_user_choice:
                _require(row["inspect_user_choice"] == "의사확인대기", "이미 선택한 의사를 변경할 수 없습니다.")
                c.execute(
                    """
                    UPDATE inspect
                    SET inspect_user_choice = %s, inspect_user_choice_at = %s
                    WHERE inspect_code = %s AND inspect_user_choice = %s
                    """, (choice.inspect_user_choice, _now(), code, "의사확인대기"),
                )
                _require(c.rowcount == 1, "사용자 선택이 변경되었습니다.")
            result=InspectResponse(**_inspect_row(c, code))
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result
