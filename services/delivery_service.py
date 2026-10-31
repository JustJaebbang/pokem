from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.delivery import DeliveryCreate, DeliveryResponse


DELIVERY_STATUS_TRANSITIONS = {
    "배송준비": "배송중",
    "배송중": "배송완료",
}


# 구매 배송은 상품, 반송 배송은 검수 대상에 연결한다.
DELIVERY_SELECT = """
    SELECT d.delivery_no, d.delivery_date, d.delivery_status,
           d.manager_manager_id, d.delivery_company_delivery_company_code,
           d.purchase_item_purchase_item_code AS purchase_item_code,
           d.return_return_no AS return_no,
           COALESCE(p.user_user_id, r.user_user_id) AS user_user_id,
           p.sell_product_sell_product_code,
           r.inspect_inspect_code
    FROM delivery d
    LEFT JOIN purchase_item p ON p.purchase_item_code = d.purchase_item_purchase_item_code
    LEFT JOIN `return` r ON r.return_no = d.return_return_no
"""


def create_delivery(db, request: DeliveryCreate, *, manage_transaction=True) -> DeliveryResponse:
    """구매의 사용자·상품 또는 반송의 사용자·검수 대상으로 배송을 등록한다."""
    # 테이블/컬럼 이름은 고정된 두 경로에서만 선택하고 입력값은 파라미터로 전달한다.
    if request.purchase_item_code is not None:
        source_table, source_key, delivery_key = "purchase_item", "purchase_item_code", "purchase_item_purchase_item_code"
        source_no, source_name = request.purchase_item_code, "구매"
        target_column, target_name = "sell_product_sell_product_code", "상품"
    else:
        source_table, source_key, delivery_key = "`return`", "return_no", "return_return_no"
        source_no, source_name = request.return_no, "반송"
        target_column, target_name = "inspect_inspect_code", "검수"
    try:
        # 검증, 일별 순번 증가, 배송 저장을 하나의 트랜잭션으로 처리한다.
        if manage_transaction:
            db.begin()
        with db.cursor() as cursor:
            # 같은 원본 건을 잠그고 구매는 상품 코드, 반송은 검수 코드를 가져온다.
            cursor.execute(
                f"""SELECT user_user_id, {target_column}
                FROM {source_table} WHERE {source_key} = %s FOR UPDATE""",
                (source_no,),
            )
            source = cursor.fetchone()
            if source is None:
                raise HTTPException(status_code=404, detail=f"{source_name} 기록을 찾을 수 없습니다.")
            if source[target_column] is None:
                raise HTTPException(status_code=409, detail=f"{source_name} 기록의 {target_name} 연결을 확인해주세요.")
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
            # 구매/반송 각각 원본 건당 한 번만 등록한다. DB UNIQUE로도 보호한다.
            cursor.execute(
                f"SELECT delivery_no FROM delivery WHERE {delivery_key} = %s FOR UPDATE",
                (source_no,),
            )
            if cursor.fetchone() is not None:
                raise HTTPException(status_code=409, detail=f"이미 배송 등록된 {source_name} 건입니다.")

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
                user_user_id=source["user_user_id"],
                sell_product_sell_product_code=source[target_column] if request.purchase_item_code is not None else None,
                inspect_inspect_code=source[target_column] if request.return_no is not None else None,
                **request.model_dump(),
            )
            cursor.execute(
                """INSERT INTO delivery (
                    delivery_no, delivery_date, delivery_status,
                    manager_manager_id, delivery_company_delivery_company_code,
                    purchase_item_purchase_item_code, return_return_no
                ) VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (delivery.delivery_no, delivery.delivery_date, delivery.delivery_status,
                 delivery.manager_manager_id,
                 delivery.delivery_company_delivery_company_code,
                 delivery.purchase_item_code, delivery.return_no),
            )
        if manage_transaction:
            db.commit()
        return delivery
    except IntegrityError as exc:
        # DB의 중복 키(1062), 외래 키(1452) 오류를 API 응답으로 변환한다.
        if manage_transaction:
            db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 배송입니다.") from exc
        if exc.args[0] == 1452:
            raise HTTPException(status_code=400, detail="연결할 배송 정보를 확인해주세요.") from exc
        raise
    except Exception:
        if manage_transaction:
            db.rollback()
        raise


def get_deliveries(db, limit=20, offset=0, user_id=None) -> list[DeliveryResponse]:
    """최신 배송부터 조회한다. 사용자는 구매/반송 모두 본인 배송만 조회한다."""
    owner_filter = "WHERE COALESCE(p.user_user_id, r.user_user_id) = %s" if user_id is not None else ""
    params = (user_id, limit, offset) if user_id is not None else (limit, offset)
    with db.cursor() as cursor:
        cursor.execute(
            f"{DELIVERY_SELECT} {owner_filter} ORDER BY d.delivery_date DESC, d.delivery_no DESC LIMIT %s OFFSET %s",
            params,
        )
        return [DeliveryResponse(**row) for row in cursor.fetchall()]


def get_delivery(db, delivery_no: str, user_id=None) -> DeliveryResponse | None:
    # 선택된 원본의 사용자로 필터링하여 다른 사용자의 반송 배송도 노출하지 않는다.
    owner_filter = " AND COALESCE(p.user_user_id, r.user_user_id) = %s" if user_id is not None else ""
    params = (delivery_no, user_id) if user_id is not None else (delivery_no,)
    with db.cursor() as cursor:
        cursor.execute(f"{DELIVERY_SELECT} WHERE d.delivery_no = %s{owner_filter}", params)
        row = cursor.fetchone()
    return DeliveryResponse(**row) if row else None


def update_delivery_status(db, delivery_no: str, status: str) -> DeliveryResponse:
    """배송준비 → 배송중 → 배송완료 순서로만 상태를 변경한다."""
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute(
                "SELECT delivery_status FROM delivery WHERE delivery_no = %s FOR UPDATE",
                (delivery_no,),
            )
            row = cursor.fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="배송 내역을 찾을 수 없습니다.")

            current = row["delivery_status"]
            if current != status:
                if DELIVERY_STATUS_TRANSITIONS.get(current) != status:
                    raise HTTPException(
                        status_code=409,
                        detail=f"배송 상태를 {current}에서 {status}(으)로 변경할 수 없습니다.",
                    )
                cursor.execute(
                    """UPDATE delivery SET delivery_status = %s
                    WHERE delivery_no = %s AND delivery_status = %s""",
                    (status, delivery_no, current),
                )
                if cursor.rowcount != 1:
                    raise HTTPException(
                        status_code=409,
                        detail="배송 상태가 변경되었습니다. 다시 확인해주세요.",
                    )

        result = get_delivery(db, delivery_no)
        if result is None:
            raise RuntimeError("변경한 배송 내역을 조회할 수 없습니다.")
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise
