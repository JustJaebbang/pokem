from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.order import OrderCreate, OrderResponse


ORDER_COLUMNS = """order_no, order_price, order_date, order_amount,
    proposal_proposal_no, case_case_code, manager_manager_id,
    product_company_product_company_code"""


def create_order(db, request: OrderCreate) -> OrderResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            # 품의 상태와 케이스를 확인하는 동안 동일 품의의 주문 등록을 직렬화한다.
            cursor.execute(
                """SELECT proposal_status, case_case_code, manager_manager_id
                FROM proposal WHERE proposal_no = %s FOR UPDATE""",
                (request.proposal_proposal_no,),
            )
            proposal = cursor.fetchone()
            if proposal is None:
                raise HTTPException(status_code=404, detail="품의를 찾을 수 없습니다.")
            if proposal["manager_manager_id"] != request.manager_manager_id:
                raise HTTPException(status_code=403, detail="품의를 작성한 매니저만 주문 담당자로 지정할 수 있습니다.")
            if proposal["proposal_status"] != "승인":
                raise HTTPException(status_code=409, detail="승인된 품의만 주문할 수 있습니다.")
            cursor.execute("SELECT manager_id FROM manager WHERE manager_id = %s FOR UPDATE", (request.manager_manager_id,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="담당 매니저를 찾을 수 없습니다.")
            cursor.execute(
                "SELECT product_company_code FROM product_company WHERE product_company_code = %s FOR UPDATE",
                (request.product_company_product_company_code,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="제조업체를 찾을 수 없습니다.")

            now = datetime.now(timezone(timedelta(hours=9)))
            # 예: 20261029000002 + 20261029. 같은 품의의 당일 중복 주문은 PK로 막는다.
            order_no = f"{request.proposal_proposal_no}{now:%Y%m%d}"
            if len(order_no) > 64:
                raise HTTPException(status_code=422, detail="품의번호와 주문일자를 합친 주문번호는 64자 이하여야 합니다.")
            result = OrderResponse(
                **request.model_dump(), order_no=order_no,
                order_date=now.strftime("%Y-%m-%d %H:%M:%S"),
                case_case_code=proposal["case_case_code"],
            )
            # ORDER는 SQL 키워드이므로 테이블 이름을 백틱으로 감싼다.
            cursor.execute(
                """INSERT INTO `order` (order_no, order_price, order_date, order_amount,
                    proposal_proposal_no, case_case_code, manager_manager_id,
                    product_company_product_company_code)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
                (result.order_no, result.order_price, result.order_date, result.order_amount,
                 result.proposal_proposal_no, result.case_case_code, result.manager_manager_id,
                 result.product_company_product_company_code),
            )
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="같은 품의로 오늘 이미 등록한 주문이 있습니다.") from exc
        if exc.args[0] == 1452:
            raise HTTPException(status_code=400, detail="연결된 품의·케이스·매니저·제조업체를 확인해주세요.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_orders(db, limit: int = 20, offset: int = 0, manager_id: str | None = None) -> list[OrderResponse]:
    # 라우터에서 로그인한 매니저 ID를 전달하여 본인 담당 주문만 조회한다.
    owner_filter = "WHERE manager_manager_id = %s" if manager_id is not None else ""
    params = (manager_id, limit, offset) if manager_id is not None else (limit, offset)
    with db.cursor() as cursor:
        cursor.execute(
            f"""SELECT {ORDER_COLUMNS} FROM `order` {owner_filter}
            ORDER BY order_date DESC, order_no DESC LIMIT %s OFFSET %s""", params,
        )
        rows = cursor.fetchall()
    return [OrderResponse(**row) for row in rows]


def get_order(db, order_no: str, manager_id: str | None = None) -> OrderResponse | None:
    owner_filter = " AND manager_manager_id = %s" if manager_id is not None else ""
    params = (order_no, manager_id) if manager_id is not None else (order_no,)
    with db.cursor() as cursor:
        cursor.execute(f"SELECT {ORDER_COLUMNS} FROM `order` WHERE order_no = %s{owner_filter}", params)
        row = cursor.fetchone()
    return OrderResponse(**row) if row else None
