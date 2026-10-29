from services.sale_registration_service import get_sale_registrations
from fastapi import HTTPException

from schemas.sell_product import SellProductCreate, SellProductResponse, SellProductUpdate, SellProductDelete
from services import post_item_service


def create_sell_product(db, sp: SellProductCreate, user_id) -> SellProductResponse:
    serial_code = f"{sp.regulation}_{sp.card_pack_type}_{sp.element_of_set}_{sp.set}_{sp.rarity}"

    try:
        db.begin()

        with db.cursor() as cursor:

            # 1. 사용자와 주소 조회
            # user_address는 실제 주소 컬럼명으로 변경
            cursor.execute(
                """
                SELECT user_id, user_address
                FROM `user`
                WHERE user_id = %s
                """,
                (user_id,),
            )
            user = cursor.fetchone()

            if user is None:
                raise HTTPException(
                    status_code=404,
                    detail="사용자가 없습니다.",
                )

            if not user["user_address"]:
                raise HTTPException(
                    status_code=400,
                    detail="주소를 먼저 등록해주세요.",
                )

            # 2. 카탈로그 조회 및 순번 발급 잠금
            # 같은 카탈로그의 다른 등록 요청은 여기서 대기
            # 카탈로그에서 같은 일련코드의 마지막 번호를 select
            cursor.execute(
                """
                SELECT cardinfo_last_sell_seq
                FROM cardinfo
                WHERE cardinfo_serial_code = %s
                FOR UPDATE
                """,
                (serial_code),
            )
            catalog = cursor.fetchone()

            if catalog is None:
                raise HTTPException(
                    status_code=404,
                    detail="카탈로그에 존재하지 않는 상품입니다.",
                )
            # seq가 같은 일련코드의 상품이 올라왔을때 구분해줌
            # 생성할 상품의 seq를 1 추가함 -> 그러면 중복이 안됨
            seq = catalog["cardinfo_last_sell_seq"] + 1
            # 판매상품코드 = 일련코드+seq
            product_code = f"{serial_code}-{seq}"

            # 3. 마지막 순번 갱신
            # 마지막 seq를 cardinfo에 저장(업데이트)
            cursor.execute(
                """
                UPDATE cardinfo
                SET cardinfo_last_sell_seq = %s
                WHERE cardinfo_serial_code = %s
                """,
                (seq, serial_code),
            )

            # 4. 판매상품 저장
            # 위 정보들(판매코드,일련코드,seq)을 가져와서 판매상품 생성
            cursor.execute(
                """
                INSERT INTO sell_product (
                    sell_product_code,
                    sell_product_serial_code,
                    seq,
                    sell_product_title,
                    sell_product_image,
                    sell_product_contents,
                    sell_product_sell_price,
                    sell_product_grade,
                    sell_product_sell_status
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    product_code, 
                    serial_code, 
                    seq,
                    sp.sell_product_title,
                    sp.sell_product_image,
                    sp.sell_product_contents,
                    sp.sell_product_sell_price,
                    sp.sell_product_grade,
                    sp.sell_product_sell_status
                ),
            )

        # 5. 같은 DB 연결로 판매등록 정보 저장
        post_item = post_item_service.insert_post_item(
            db=db,
            user_id=user["user_id"],
            region=user["user_address"],
            product_code=product_code,
        )

        # 6. 두 테이블 저장이 모두 성공하면 확정
        db.commit()

    except Exception:
        db.rollback()
        raise

    # 생성하고 아래 함수를 통해 어떤 상품 생성했는지 보여주기
    return get_sell_product_code(db, product_code)


# 전체 sell_product 정보 가져오기
def get_sell_product(db) -> list[SellProductResponse] | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM sell_product
            """,
        )
        rows = cursor.fetchall()

    return [SellProductResponse(**row) for row in rows]


# sell_product_code에 해당하는 sell_product 정보 가져오기
def get_sell_product_code(db, sell_product_code: str) -> SellProductResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT *
            FROM sell_product
            WHERE sell_product_code = %s
            """,
            (sell_product_code),
        )
        row = cursor.fetchone()

    return SellProductResponse(**row) if row else None


# sell_product_code에 해당하는 sell_product 정보 변경하기
def put_sell_product_code(db, sp: SellProductUpdate, sell_product_code: str) -> SellProductResponse | None:
    try:
        with db.cursor() as cursor:
            cursor.execute(
                """
                UPDATE sell_product
                SET sell_product_title = %s,
                    sell_product_image = %s,
                    sell_product_contents = %s,
                    sell_product_sell_price = %s
                WHERE sell_product_code = %s
                """,
                (
                    sp.sell_product_title, 
                    sp.sell_product_image, 
                    sp.sell_product_contents,
                    sp.sell_product_sell_price, 
                    sell_product_code
                ),
            )
        # row = cursor.fetchone()

    # return get_sell_product_code(db, sell_product_code)
    # return SellProductResponse(**row) if row else None

        db.commit()

    except Exception:
        db.rollback()
        raise

    # 변경하고 아래 함수를 통해 어떤 상품 어떻게 변경했는지 보여주기
    return get_sell_product_code(db, sell_product_code)


# sell_product_code에 해당하는 sell_product 삭제하기
def delete_sell_product_code(db, sell_product_code: str) -> SellProductDelete | None:
    try:
        with db.cursor() as cursor:
            cursor.execute(
                """
                SELECT *
                FROM sell_product
                WHERE sell_product_code = %s
                FOR UPDATE
                """,
                (sell_product_code),
            )
            product = cursor.fetchone()

            if product is None:
                db.rollback()
                return None

            cursor.execute(
                """
                DELETE
                FROM sell_product
                WHERE sell_product_code = %s
                """,
                (sell_product_code),
            )

        db.commit()
    
    except Exception:
        db.rollback()
        raise

    return {
        "message": "해당 판매상품이 삭제되었습니다.",
        "sell_product_code": product['sell_product_code'],
        "sell_product_serial_code": product['sell_product_serial_code'],
        "seq": product['seq'],
        "sell_product_title": product['sell_product_title'],
        "sell_product_image": product['sell_product_image'],
        "sell_product_contents": product['sell_product_contents'],
        "sell_product_sell_price": product['sell_product_sell_price'],
        "sell_product_grade": product['sell_product_grade'],
        "sell_product_sell_status": product['sell_product_sell_status'],
    }

# 환불 승인된 상품만 판매자가 명시적으로 재판매합니다.
def relist_sell_product(db, product_code: str, seller_id: str, role: str = "user") -> SellProductResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            if role == "manager":
                cursor.execute(
                    """
                    SELECT manager_id
                    FROM manager
                    WHERE manager_id = %s
                    FOR UPDATE
                    """, (seller_id,),
                )
            else:
                cursor.execute(
                    """
                    SELECT user_id
                    FROM `user`
                    WHERE user_id = %s
                    FOR UPDATE
                    """, (seller_id,),
                )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다.")
            cursor.execute(
                """
                SELECT *
                FROM sell_product
                WHERE sell_product_code = %s
                FOR UPDATE
                """, (product_code,),
            )
            product = cursor.fetchone()
            if product is None:
                raise HTTPException(status_code=404, detail="판매상품을 찾을 수 없습니다.")
            posts = get_sale_registrations(cursor, product_code)
            allowed = len(posts) == 1 and (
                role == "manager" if posts[0].get("registration_type", "direct") == "consign"
                else role == "user" and posts[0]["user_user_id"] == seller_id
            )
            if not allowed:
                raise HTTPException(status_code=403, detail="판매자만 재판매할 수 있습니다.")
            if product["sell_product_sell_status"] != "거래취소" or posts[0]["post_item_complete_date"] is not None:
                raise HTTPException(status_code=409, detail="거래취소된 상품만 재판매할 수 있습니다.")
            cursor.execute(
                """
                SELECT purchase_item_code
                FROM purchase_item
                WHERE sell_product_sell_product_code = %s AND purchase_item_status <> %s
                FOR UPDATE
                """, (product_code, "거래취소"),
            )
            if cursor.fetchone() is not None:
                raise HTTPException(status_code=409, detail="종료되지 않은 구매 건이 있습니다.")
            cursor.execute(
                """
                UPDATE sell_product
                SET sell_product_sell_status = %s
                WHERE sell_product_code = %s AND sell_product_sell_status = %s
                """, ("판매중", product_code, "거래취소"),
            )
            if cursor.rowcount != 1:
                raise HTTPException(status_code=409, detail="상품 상태가 변경되었습니다.")
            result = SellProductResponse(**{**product, "sell_product_sell_status": "판매중"})
        db.commit()
    except Exception:
        db.rollback()
        raise
    return result
