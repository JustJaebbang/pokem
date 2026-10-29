from secrets import randbelow
from fastapi import HTTPException
from pymysql.err import IntegrityError
from schemas.inspection_request import RequestResponse
from services.inspection_common import _now, _require


def create_request(db, request, user_id):
    # 기존 14자리 신청번호 길이를 유지하고 기본키 충돌만 재시도합니다.
    for attempt in range(3):
        try:
            db.begin()
            result = RequestResponse(inspection_request_no=f"{randbelow(10**14):014d}",
                inspection_request_date=_now(), inspection_request_amount=request.inspection_request_amount,
                user_user_id=user_id, manager_manager_id=None)
            with db.cursor() as c:
                c.execute(
                    """
                    SELECT user_id
                    FROM `user`
                    WHERE user_id = %s
                    FOR UPDATE
                    """, (user_id,),
                )
                _require(c.fetchone() is not None, "사용자를 찾을 수 없습니다.", 404)
                c.execute(
                    """
                    INSERT INTO inspection_request (
                        inspection_request_no, inspection_request_date, inspection_request_amount, user_user_id
                    )
                    VALUES (%s, %s, %s, %s)
                    """, (result.inspection_request_no, result.inspection_request_date,
                          result.inspection_request_amount, user_id),
                )
            db.commit()
            return result
        except IntegrityError as exc:
            db.rollback()
            if exc.args[0] != 1062:
                raise
            if attempt == 2:
                raise HTTPException(status_code=409, detail="신청번호 생성에 실패했습니다. 다시 요청해주세요.") from exc
        except Exception:
            db.rollback()
            raise


def get_requests(db, current, request_no=None):
    query = """
        SELECT *
        FROM inspection_request
        WHERE 1 = 1
    """
    params=[]
    if request_no is not None:
        query += "\n AND inspection_request_no = %s"
        params.append(request_no)
    if current.role != "manager":
        query += "\n AND user_user_id = %s"
        params.append(current.account.user_id)
    query += "\n ORDER BY inspection_request_date DESC, inspection_request_no DESC"
    with db.cursor() as c:
        c.execute(query, tuple(params))
        rows=c.fetchall()
    if request_no is not None:
        _require(bool(rows), "신청을 찾을 수 없거나 조회 권한이 없습니다.", 404)
        return RequestResponse(**rows[0])
    return [RequestResponse(**r) for r in rows]
