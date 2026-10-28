from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import HTTPException

from schemas.pay import PayCreate, PayResponse, PayUpdate


def create_pay(db, request: PayCreate) -> PayResponse:
    """호출자의 트랜잭션 안에서 결제를 생성한다. commit/rollback은 호출자가 한다."""
    with db.cursor() as cursor:
        # 같은 요청의 중복 결제 생성을 막고, ID는 클라이언트 입력 대신 DB에서 가져온다.
        cursor.execute(
            """
            SELECT user_user_id, manager_manager_id FROM inspection_request
            WHERE inspection_request_no = %s FOR UPDATE
            """,
            (request.inspection_request_inspection_request_no,),
        )
        inspection = cursor.fetchone()
        if inspection is None:
            raise HTTPException(status_code=404, detail="해당 검수 요청을 찾을 수 없습니다.")
        if inspection["manager_manager_id"] is None:
            raise HTTPException(status_code=409, detail="매니저 확인이 완료되지 않은 요청입니다.")
        cursor.execute(
            "SELECT pay_no FROM pay WHERE inspection_request_inspection_request_no = %s FOR UPDATE",
            (request.inspection_request_inspection_request_no,),
        )
        if cursor.fetchone() is not None:
            raise HTTPException(status_code=409, detail="이미 결제가 생성된 검수 요청입니다.")

        now = datetime.now(ZoneInfo("Asia/Seoul"))
        pay = PayResponse(
            pay_no=f"{request.inspection_request_inspection_request_no}{now:%Y%m%d}",
            pay_status="결제대기",
            # 매니저가 입력한 최종 금액을 저장한다.
            pay_price=request.pay_price,
            pay_date=now.strftime("%Y-%m-%d %H:%M:%S"),
            user_user_id=inspection["user_user_id"],
            manager_manager_id=inspection["manager_manager_id"],
            inspection_request_inspection_request_no=request.inspection_request_inspection_request_no,
        )
        cursor.execute(
            """
            INSERT INTO pay (
                pay_no, pay_status, pay_price, pay_date,
                user_user_id, manager_manager_id, inspection_request_inspection_request_no
            ) VALUES (%s, %s, %s, %s, %s, %s, %s)
            """,
            (
                pay.pay_no, pay.pay_status, pay.pay_price, pay.pay_date,
                pay.user_user_id, pay.manager_manager_id,
                pay.inspection_request_inspection_request_no,
            ),
        )
    return pay


def get_pays(db, limit: int = 20, offset: int = 0) -> list[PayResponse]:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT pay_no, pay_status, pay_price, pay_date,
                   user_user_id, manager_manager_id, inspection_request_inspection_request_no
            FROM pay ORDER BY pay_date DESC, pay_no DESC LIMIT %s OFFSET %s
            """,
            (limit, offset),
        )
        rows = cursor.fetchall()
    return [PayResponse(**row) for row in rows]


def get_pay(db, pay_no: str) -> PayResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT pay_no, pay_status, pay_price, pay_date,
                   user_user_id, manager_manager_id, inspection_request_inspection_request_no
            FROM pay WHERE pay_no = %s
            """,
            (pay_no,),
        )
        row = cursor.fetchone()
    return PayResponse(**row) if row else None


def update_pay(db, pay_no: str, request: PayUpdate) -> PayResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            # 같은 값으로 수정해도 404가 되지 않도록 rowcount 대신 존재 여부를 확인한다.
            cursor.execute("SELECT pay_no FROM pay WHERE pay_no = %s FOR UPDATE", (pay_no,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="해당 결제를 찾을 수 없습니다.")

            changes = request.model_dump(exclude_unset=True)
            # 컬럼명은 고정된 허용 목록으로 만들고, 값은 SQL 파라미터로 전달한다.
            columns = [name for name in ("pay_status", "pay_price") if name in changes]
            assignments = ", ".join(f"{name} = %s" for name in columns)
            cursor.execute(
                f"UPDATE pay SET {assignments} WHERE pay_no = %s",
                tuple(changes[name] for name in columns) + (pay_no,),
            )
        result = get_pay(db, pay_no)
        if result is None:
            raise RuntimeError("변경한 결제를 조회할 수 없습니다.")
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise
