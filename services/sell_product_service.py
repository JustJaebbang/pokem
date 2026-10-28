from fastapi import HTTPException

from schemas.sell_product import SellProductCreate, SellProductResponse
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
        # 생성하고 아래 함수를 통해 어떤 상품 생성했는지 보여주기
        return get_sell_product_code(db, product_code)

    except Exception:
        db.rollback()
        raise


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
def put_sell_product_code(db, sp: SellProductCreate, sell_product_code: str) -> SellProductResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            UPDATE sell_product
            SET sell_product_title = %s,
                sell_product_image = %s,
                sell_product_contents = %s,
                sell_product_sell_price = %s,
            WHERE sell_product_code = %s
            """,
            (
                sp.sell_product_title, 
                sp.sell_product_image, 
                sp.sell_product_contents,
                sp.sell_product_price, 
                sell_product_code
            ),
        )
        # row = cursor.fetchone()

    return get_sell_product_code(db, sell_product_code)
    # return SellProductResponse(**row) if row else None
