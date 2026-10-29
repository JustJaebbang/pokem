from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.receipt import ReceiptCreate, ReceiptResponse


RECEIPT_COLUMNS = """receipt_no, receipt_date, receipt_amount, pay_pay_no,
    user_user_id, manager_manager_id, sell_product_sell_product_code"""


def create_receipt(db, request: ReceiptCreate) -> ReceiptResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            # 사용자 ID를 요청으로 받지 않고 결제에서 가져온다.
            # 같은 결제의 동시 등록은 결제 행 잠금으로 직렬화한다.
            cursor.execute("SELECT user_user_id FROM pay WHERE pay_no = %s FOR UPDATE", (request.pay_pay_no,))
            pay = cursor.fetchone()
            if pay is None:
                raise HTTPException(status_code=404, detail="결제를 찾을 수 없습니다.")
            cursor.execute("SELECT manager_id FROM manager WHERE manager_id = %s FOR UPDATE", (request.manager_manager_id,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="등록 매니저를 찾을 수 없습니다.")
            cursor.execute(
                "SELECT sell_product_code FROM sell_product WHERE sell_product_code = %s FOR UPDATE",
                (request.sell_product_sell_product_code,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="상품을 찾을 수 없습니다.")

            now = datetime.now(timezone(timedelta(hours=9)))
            # 결제번호 + 날짜 YYYYMMDD. 별도 순번이나 구분 문자는 붙이지 않는다.
            receipt_no = f"{request.pay_pay_no}{now:%Y%m%d}"
            if len(receipt_no) > 64:
                raise HTTPException(status_code=422, detail="결제번호와 접수일자를 합친 접수번호는 64자 이하여야 합니다.")
            result = ReceiptResponse(
                **request.model_dump(), receipt_no=receipt_no,
                receipt_date=now.strftime("%Y-%m-%d %H:%M:%S"),
                user_user_id=pay["user_user_id"],
            )
            cursor.execute(
                """INSERT INTO receipt (receipt_no, receipt_date, receipt_amount, pay_pay_no,
                    user_user_id, manager_manager_id, sell_product_sell_product_code)
                VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (result.receipt_no, result.receipt_date, result.receipt_amount, result.pay_pay_no,
                 result.user_user_id, result.manager_manager_id, result.sell_product_sell_product_code),
            )
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="해당 결제로 오늘 이미 등록한 접수 내역이 있습니다.") from exc
        if exc.args[0] == 1452:
            raise HTTPException(status_code=400, detail="연결된 결제·사용자·매니저·상품을 확인해주세요.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_receipts(db, limit: int = 20, offset: int = 0, user_id: str | None = None) -> list[ReceiptResponse]:
    owner_filter = "WHERE user_user_id = %s" if user_id is not None else ""
    params = (user_id, limit, offset) if user_id is not None else (limit, offset)
    with db.cursor() as cursor:
        cursor.execute(
            f"""SELECT {RECEIPT_COLUMNS} FROM receipt {owner_filter}
            ORDER BY receipt_date DESC, receipt_no DESC LIMIT %s OFFSET %s""", params,
        )
        rows = cursor.fetchall()
    return [ReceiptResponse(**row) for row in rows]


def get_receipt(db, receipt_no: str, user_id: str | None = None) -> ReceiptResponse | None:
    owner_filter = " AND user_user_id = %s" if user_id is not None else ""
    params = (receipt_no, user_id) if user_id is not None else (receipt_no,)
    with db.cursor() as cursor:
        cursor.execute(f"SELECT {RECEIPT_COLUMNS} FROM receipt WHERE receipt_no = %s{owner_filter}", params)
        row = cursor.fetchone()
    return ReceiptResponse(**row) if row else None
