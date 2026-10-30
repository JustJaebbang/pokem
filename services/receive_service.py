from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.receive import ReceiveCreate, ReceiveResponse


RECEIVE_COLUMNS = """receive_no, receive_price, receive_date, receive_amount,
    order_order_no, manager_manager_id, product_company_product_company_code"""


def create_receive(db, request: ReceiveCreate) -> ReceiveResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            # 주문 행을 먼저 잠가 같은 주문에 대한 입고 수량 검사를 직렬화한다.
            cursor.execute(
                """SELECT order_amount, case_case_code, manager_manager_id,
                    product_company_product_company_code
                FROM `order` WHERE order_no = %s FOR UPDATE""", (request.order_order_no,),
            )
            order = cursor.fetchone()
            if order is None:
                raise HTTPException(status_code=404, detail="주문을 찾을 수 없습니다.")
            if order["manager_manager_id"] != request.manager_manager_id:
                raise HTTPException(status_code=403, detail="주문 담당 매니저만 입고 담당자로 지정할 수 있습니다.")
            cursor.execute("SELECT manager_id FROM manager WHERE manager_id = %s FOR UPDATE", (request.manager_manager_id,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="담당 매니저를 찾을 수 없습니다.")

            now = datetime.now(timezone(timedelta(hours=9)))
            receive_no = f"{request.order_order_no}{now:%Y%m%d}"
            if len(receive_no) > 64:
                raise HTTPException(status_code=422, detail="주문번호와 입고일자를 합친 입고번호는 64자 이하여야 합니다.")
            cursor.execute(
                "SELECT receive_no, receive_amount FROM receive WHERE order_order_no = %s FOR UPDATE",
                (request.order_order_no,),
            )
            previous = cursor.fetchall()
            if any(row["receive_no"] == receive_no for row in previous):
                raise HTTPException(status_code=409, detail="같은 주문으로 오늘 이미 등록한 입고가 있습니다.")
            # 기존 수량이 불명확한 경우에도 초과 입고를 허용하지 않는다.
            if order["order_amount"] is None or any(row["receive_amount"] is None or row["receive_amount"] < 0 for row in previous):
                raise HTTPException(status_code=409, detail="기존 주문 또는 입고 수량을 확인해주세요.")
            received = sum(row["receive_amount"] for row in previous)
            if received + request.receive_amount > order["order_amount"]:
                raise HTTPException(status_code=409, detail="누적 입고 수량이 주문 수량을 초과합니다.")

            cursor.execute("SELECT case_stock FROM `case` WHERE case_code = %s FOR UPDATE", (order["case_case_code"],))
            case = cursor.fetchone()
            if case is None:
                raise HTTPException(status_code=404, detail="주문에 연결된 케이스를 찾을 수 없습니다.")
            if case["case_stock"] + request.receive_amount > 2147483647:
                raise HTTPException(status_code=409, detail="케이스 재고가 DB 저장 한도를 초과합니다.")
            result = ReceiveResponse(
                **request.model_dump(), receive_no=receive_no,
                receive_date=now.strftime("%Y-%m-%d %H:%M:%S"),
                product_company_product_company_code=order["product_company_product_company_code"],
            )
            cursor.execute(
                """INSERT INTO receive (receive_no, receive_price, receive_date, receive_amount,
                    order_order_no, manager_manager_id, product_company_product_company_code)
                VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (result.receive_no, result.receive_price, result.receive_date, result.receive_amount,
                 result.order_order_no, result.manager_manager_id, result.product_company_product_company_code),
            )
            # 입고 기록과 재고 증가는 함께 커밋하거나 함께 롤백한다.
            cursor.execute(
                "UPDATE `case` SET case_stock = case_stock + %s WHERE case_code = %s",
                (request.receive_amount, order["case_case_code"]),
            )
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 입고번호입니다.") from exc
        if exc.args[0] == 1452:
            raise HTTPException(status_code=400, detail="연결된 주문·매니저·제조업체를 확인해주세요.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_receives(db, limit: int = 20, offset: int = 0, manager_id: str | None = None) -> list[ReceiveResponse]:
    owner_filter = "WHERE manager_manager_id = %s" if manager_id is not None else ""
    params = (manager_id, limit, offset) if manager_id is not None else (limit, offset)
    with db.cursor() as cursor:
        cursor.execute(
            f"""SELECT {RECEIVE_COLUMNS} FROM receive {owner_filter}
            ORDER BY receive_date DESC, receive_no DESC LIMIT %s OFFSET %s""", params,
        )
        rows = cursor.fetchall()
    return [ReceiveResponse(**row) for row in rows]


def get_receive(db, receive_no: str, manager_id: str | None = None) -> ReceiveResponse | None:
    owner_filter = " AND manager_manager_id = %s" if manager_id is not None else ""
    params = (receive_no, manager_id) if manager_id is not None else (receive_no,)
    with db.cursor() as cursor:
        cursor.execute(f"SELECT {RECEIVE_COLUMNS} FROM receive WHERE receive_no = %s{owner_filter}", params)
        row = cursor.fetchone()
    return ReceiveResponse(**row) if row else None
