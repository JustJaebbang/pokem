from uuid import uuid4

from schemas.return_item import ReturnResponse
from services.inspection_common import _require


RETURN_SELECT = """
    SELECT return_no, inspect_inspect_code, user_user_id, manager_manager_id
    FROM `return`
"""


def ensure_return(c, inspect):
    """검수 행 잠금을 보유한 호출자의 트랜잭션 안에서만 호출한다."""
    _require(inspect["inspect_status"] == "검수완료", "검수가 완료되지 않았습니다.")
    _require(inspect["inspect_user_choice"] == "반환", "반환을 선택한 물품만 접수할 수 있습니다.")
    c.execute("SELECT return_no FROM `return` WHERE inspect_inspect_code = %s FOR UPDATE",
              (inspect["inspect_code"],))
    if c.fetchone() is not None:
        return
    c.execute(
        """INSERT INTO `return` (
            return_no, inspect_inspect_code, user_user_id
        ) VALUES (%s, %s, %s)""",
        (f"RET_{uuid4().hex}", inspect["inspect_code"], inspect["user_user_id"]),
    )


def get_returns(db, user_id=None, limit=20, offset=0):
    where = " WHERE user_user_id = %s" if user_id is not None else ""
    params = (user_id, limit, offset) if user_id is not None else (limit, offset)
    with db.cursor() as c:
        c.execute(RETURN_SELECT + where + " ORDER BY (SELECT i.inspect_user_choice_at FROM inspect i WHERE i.inspect_code = `return`.inspect_inspect_code) DESC, return_no DESC LIMIT %s OFFSET %s", params)
        return [ReturnResponse(**row) for row in c.fetchall()]


def get_return(db, return_no, user_id=None):
    where = " AND user_user_id = %s" if user_id is not None else ""
    params = (return_no, user_id) if user_id is not None else (return_no,)
    with db.cursor() as c:
        c.execute(RETURN_SELECT + " WHERE return_no = %s" + where, params)
        row = c.fetchone()
    _require(row is not None, "반환 내역을 찾을 수 없습니다.", 404)
    return ReturnResponse(**row)


def assign_manager(db, return_no, manager_id):
    try:
        db.begin()
        with db.cursor() as c:
            c.execute(RETURN_SELECT + " WHERE return_no = %s FOR UPDATE", (return_no,))
            row = c.fetchone()
            _require(row is not None, "반환 내역을 찾을 수 없습니다.", 404)
            _require(row["manager_manager_id"] is None,
                     "이미 담당자가 배정된 반환입니다.")
            c.execute("SELECT manager_id FROM manager WHERE manager_id = %s FOR UPDATE", (manager_id,))
            _require(c.fetchone() is not None, "매니저를 찾을 수 없습니다.", 404)
            c.execute("""UPDATE `return` SET manager_manager_id = %s
                         WHERE return_no = %s AND manager_manager_id IS NULL""",
                      (manager_id, return_no))
            _require(c.rowcount == 1, "담당 매니저를 배정할 수 없습니다.")
        result = get_return(db, return_no)
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise

