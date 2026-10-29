from datetime import datetime

from fastapi import HTTPException

from schemas.cybermoney_pay import CybermoneyPayResponse, CybermoneyPayCreateResponse


# 호출자가 사용자 행을 잠그고 트랜잭션을 관리합니다. 여기서는 commit하지 않습니다.
def deduct_cybermoney(db, user_id: str, price: int, balance: int) -> int:
    if price is None or price <= 0:
        raise HTTPException(status_code=409, detail="상품의 결제 금액을 확인해주세요.")
    if balance < price:
        raise HTTPException(status_code=409, detail="사이버머니 잔액이 부족합니다.")
    with db.cursor() as cursor:
        cursor.execute(
            """
            UPDATE `user`
            SET user_money = user_money - %s
            WHERE user_id = %s
                AND user_money >= %s
            """,
            (price, user_id, price),
        )
        if cursor.rowcount != 1:
            raise HTTPException(status_code=409, detail="잔액을 변경할 수 없습니다. 다시 확인해주세요.")
    return balance - price


# 같은 연결에서 purchase_item을 INSERT한 뒤 호출합니다. 외래 키 검사는 유지합니다.
def insert_cybermoney_pay(
    db, purchase_code: str, user_id: str, price: int, balance: int, paid_at: datetime
) -> CybermoneyPayCreateResponse:
    result = CybermoneyPayCreateResponse(
        message="사이버머니 결제가 완료되었습니다.",
        cybermoney_pay_code=f"{purchase_code}_{paid_at.strftime('%Y%m%d%H%M%S%f')}",
        cybermoney_pay_status="결제완료",
        cybermoney_pay_date=paid_at.isoformat(timespec="seconds"),
        cybermoney_pay_price=price,
        purchase_item_purchase_item_code=purchase_code,
        user_user_id=user_id,
        user_money=balance,
    )
    with db.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO cybermoney_pay (
                cybermoney_pay_code,
                cybermoney_pay_status,
                cybermoney_pay_date,
                cybermoney_pay_price,
                purchase_item_purchase_item_code
            )
            VALUES (%s, %s, %s, %s, %s)
            """,
            (result.cybermoney_pay_code, result.cybermoney_pay_status,
             result.cybermoney_pay_date, price, purchase_code),
        )
    return result


def get_cybermoney_pay(db, user_id: str) -> list[CybermoneyPayResponse]:
    with db.cursor() as cursor:
        # 상황	현재 응답
        # 사용자가 없음	-> 404
        # 사용자는 있지만 결제 내역 없음 -> []
        # 첫 번째 SQL을 제거하면 두 상황 모두 []가 됩니다.
        # 일반 사용자는 인증 단계에서 이미 계정 존재를 확인하므로 중복 확인에 가깝습니다. 
        # 다만 관리자가 다른 사용자 ID로 조회할 때 해당 사용자가 존재하는지 구분하는 역할이 있습니다.
        # 이 구분이 필요 없다면 제거해도 됩니다. 해당 SQL은 현재 유지했습니다.

        # 이 SQL문이 왜 필요한지 물어봤는데 위 답변을 해줌. 그래서 유지
        cursor.execute(
            """
            SELECT user_id
            FROM `user`
            WHERE user_id = %s
            """,
            (user_id,),
        )
        if cursor.fetchone() is None:
            raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
        cursor.execute(
            """
            SELECT cp.*, pi.user_user_id
            FROM cybermoney_pay cp
            JOIN purchase_item pi
                ON pi.purchase_item_code = cp.purchase_item_purchase_item_code
            WHERE pi.user_user_id = %s
            ORDER BY cp.cybermoney_pay_date DESC, cp.cybermoney_pay_code DESC
            """,
            (user_id,),
        )
        rows = cursor.fetchall()
    return [CybermoneyPayResponse(**row) for row in rows]


def get_cybermoney_pay_code(db, cybermoney_pay_code: str) -> CybermoneyPayResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT cp.*, pi.user_user_id
            FROM cybermoney_pay cp
            JOIN purchase_item pi
                ON pi.purchase_item_code = cp.purchase_item_purchase_item_code
            WHERE cp.cybermoney_pay_code = %s
            """,
            (cybermoney_pay_code,),
        )
        row = cursor.fetchone()
    return CybermoneyPayResponse(**row) if row else None
