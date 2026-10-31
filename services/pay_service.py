from inspection_pricing import calculate_inspection_fee
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
            SELECT user_user_id, manager_manager_id, inspection_request_amount FROM inspection_request
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

        try:
            price = calculate_inspection_fee(inspection["inspection_request_amount"])
        except ValueError as exc:
            raise HTTPException(status_code=409, detail="검수 수량이 없거나 결제 가능한 범위를 초과했습니다.") from exc
        now = datetime.now(ZoneInfo("Asia/Seoul"))
        pay = PayResponse(
            pay_no=f"{request.inspection_request_inspection_request_no}{now:%Y%m%d}",
            pay_status="결제대기",
            # 승인된 신청의 저장된 수량으로만 계산한다.
            pay_price=price,
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


def get_pays(db, limit: int = 20, offset: int = 0, user_id: str | None = None, request_no: str | None = None) -> list[PayResponse]:
    conditions = []
    params = []
    if user_id is not None:
        conditions.append("user_user_id = %s")
        params.append(user_id)
    if request_no is not None:
        conditions.append("inspection_request_inspection_request_no = %s")
        params.append(request_no)
    owner_filter = "WHERE " + " AND ".join(conditions) if conditions else ""
    params.extend((limit, offset))
    with db.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT pay_no, pay_status, pay_price, pay_date,
                   user_user_id, manager_manager_id, inspection_request_inspection_request_no
            FROM pay {owner_filter} ORDER BY pay_date DESC, pay_no DESC LIMIT %s OFFSET %s
            """,
            tuple(params),
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
            columns = [name for name in ("pay_status",) if name in changes]
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


def complete_pay(db, pay_no: str, user_id: str, expected_price: int) -> PayResponse:
    """사용자 버튼으로 상태만 완료한다. 외부 결제나 포켐머니 차감은 하지 않는다."""
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute("SELECT * FROM pay WHERE pay_no = %s FOR UPDATE", (pay_no,))
            row = cursor.fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="해당 결제를 찾을 수 없습니다.")
            if row["user_user_id"] != user_id:
                raise HTTPException(status_code=403, detail="본인의 검수비만 결제할 수 있습니다.")
            if row["pay_status"] != "결제완료":
                if row["pay_status"] != "결제대기":
                    raise HTTPException(status_code=409, detail="결제대기 상태에서만 결제할 수 있습니다.")
                price = row["pay_price"]
                if price is None or price < 0:
                    raise HTTPException(status_code=409, detail="검수비 금액을 확인해주세요.")
                if price != expected_price:
                    raise HTTPException(status_code=409, detail="검수비가 변경되었습니다. 금액을 다시 확인해주세요.")
                cursor.execute("UPDATE pay SET pay_status = %s WHERE pay_no = %s AND pay_status = %s",
                               ("결제완료", pay_no, "결제대기"))
                if cursor.rowcount != 1:
                    raise HTTPException(status_code=409, detail="결제 상태가 변경되었습니다. 다시 확인해주세요.")
                row["pay_status"] = "결제완료"
            result = PayResponse(**row)
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise
