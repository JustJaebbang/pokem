from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.delivery import DeliveryCreate, DeliveryResponse


# 응답에는 구매번호를 간단한 이름으로 노출하고 구매자·상품은 JOIN으로 가져온다.
DELIVERY_SELECT = """
    SELECT d.delivery_no, d.delivery_date, d.delivery_status,
           d.manager_manager_id, d.delivery_company_delivery_company_code,
           d.purchase_item_purchase_item_code AS purchase_item_code,
           p.user_user_id, p.sell_product_sell_product_code
    FROM delivery d
    JOIN purchase_item p ON p.purchase_item_code = d.purchase_item_purchase_item_code
"""


def create_delivery(db, request: DeliveryCreate) -> DeliveryResponse:
    """구매자에게 보낼 상품과 배송업체를 연결하고 배송준비 상태로 등록한다."""
    try:
        # 검증, 일별 순번 증가, 배송 저장을 하나의 트랜잭션으로 처리한다.
        db.begin()
        with db.cursor() as cursor:
            # 같은 구매 건의 동시 등록을 직렬화하고 수령자·상품을 함께 가져온다.
            cursor.execute(
                """SELECT user_user_id, sell_product_sell_product_code
                FROM purchase_item WHERE purchase_item_code = %s FOR UPDATE""",
                (request.purchase_item_code,),
            )
            purchase = cursor.fetchone()
            if purchase is None:
                raise HTTPException(status_code=404, detail="구매 기록을 찾을 수 없습니다.")
            # 배송에 연결할 매니저와 배송업체가 실제로 존재하는지 확인한다.
            cursor.execute(
                "SELECT manager_id FROM manager WHERE manager_id = %s FOR UPDATE",
                (request.manager_manager_id,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="매니저를 찾을 수 없습니다.")
            cursor.execute(
                "SELECT delivery_company_code FROM delivery_company WHERE delivery_company_code = %s FOR UPDATE",
                (request.delivery_company_delivery_company_code,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="배송업체를 찾을 수 없습니다.")
            # 구매 건당 한 번만 등록한다. DB UNIQUE 제약으로도 중복을 막는다.
            cursor.execute(
                "SELECT delivery_no FROM delivery WHERE purchase_item_purchase_item_code = %s FOR UPDATE",
                (request.purchase_item_code,),
            )
            if cursor.fetchone() is not None:
                raise HTTPException(status_code=409, detail="이미 배송 등록된 구매 건입니다.")

            # 서버 시간대와 관계없이 한국 날짜를 배송번호와 순번의 기준으로 삼는다.
            now = datetime.now(timezone(timedelta(hours=9)))
            # 날짜별 첫 등록은 1, 이후 등록은 1씩 증가한다.
            # UPDATE가 잡은 행 잠금은 커밋까지 유지되어 동시 요청의 순번이 겹치지 않는다.
            cursor.execute(
                """INSERT INTO delivery_sequence (delivery_date, last_seq) VALUES (%s, 1)
                ON DUPLICATE KEY UPDATE last_seq = last_seq + 1""",
                (now.date(),),
            )
            cursor.execute(
                "SELECT last_seq FROM delivery_sequence WHERE delivery_date = %s FOR UPDATE",
                (now.date(),),
            )
            seq = cursor.fetchone()["last_seq"]
            # 6자리 범위를 초과하면 순번 증가를 포함한 전체 작업을 롤백한다.
            if seq > 999999:
                raise HTTPException(status_code=409, detail="일일 배송 등록 한도를 초과했습니다.")
            # 예: 20261029000001 = 등록일 YYYYMMDD + 일별 순번 000001.
            delivery = DeliveryResponse(
                delivery_no=f"{now:%Y%m%d}{seq:06d}",
                delivery_date=now.strftime("%Y-%m-%d %H:%M:%S"),
                delivery_status="배송준비",
                user_user_id=purchase["user_user_id"],
                sell_product_sell_product_code=purchase["sell_product_sell_product_code"],
                **request.model_dump(),
            )
            cursor.execute(
                """INSERT INTO delivery (
                    delivery_no, delivery_date, delivery_status,
                    manager_manager_id, delivery_company_delivery_company_code,
                    purchase_item_purchase_item_code
                ) VALUES (%s, %s, %s, %s, %s, %s)""",
                (delivery.delivery_no, delivery.delivery_date, delivery.delivery_status,
                 delivery.manager_manager_id,
                 delivery.delivery_company_delivery_company_code,
                 delivery.purchase_item_code),
            )
        db.commit()
        return delivery
    except IntegrityError as exc:
        # DB의 중복 키(1062), 외래 키(1452) 오류를 API 응답으로 변환한다.
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 배송입니다.") from exc
        if exc.args[0] == 1452:
            raise HTTPException(status_code=400, detail="연결할 배송 정보를 확인해주세요.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_deliveries(db, limit=20, offset=0, user_id=None) -> list[DeliveryResponse]:
    """최신 배송부터 조회한다. user_id가 주어지면 해당 구매자의 내역만 반환한다."""
    owner_filter = "WHERE p.user_user_id = %s" if user_id is not None else ""
    params = (user_id, limit, offset) if user_id is not None else (limit, offset)
    with db.cursor() as cursor:
        cursor.execute(
            f"{DELIVERY_SELECT} {owner_filter} ORDER BY d.delivery_date DESC, d.delivery_no DESC LIMIT %s OFFSET %s",
            params,
        )
        return [DeliveryResponse(**row) for row in cursor.fetchall()]


def get_delivery(db, delivery_no: str, user_id=None) -> DeliveryResponse | None:
    # 구매자 조건을 SQL에 포함하여 다른 사용자의 배송 내역이 반환되지 않도록 한다.
    owner_filter = " AND p.user_user_id = %s" if user_id is not None else ""
    params = (delivery_no, user_id) if user_id is not None else (delivery_no,)
    with db.cursor() as cursor:
        cursor.execute(f"{DELIVERY_SELECT} WHERE d.delivery_no = %s{owner_filter}", params)
        row = cursor.fetchone()
    return DeliveryResponse(**row) if row else None
