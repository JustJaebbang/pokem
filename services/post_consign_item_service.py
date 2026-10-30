from uuid import uuid4
from fastapi import HTTPException
from pymysql.err import IntegrityError
from schemas.post_consign_item import ConsignResponse, ConsignCreateResponse
from schemas.sell_product import SellProductResponse
from services.inspection_common import _now, _require, _inspect_row


def create_consign(db, request, manager_id):
    try:
        db.begin()
        with db.cursor() as c:
            item=_inspect_row(c, request.inspect_inspect_code, lock=True)
            _require(item["inspect_status"] == "검수완료" and item["inspect_user_choice"] == "대리판매",
                     "검수 완료 후 대리판매를 선택한 상품만 등록할 수 있습니다.")
            c.execute(
                """
                SELECT post_consign_item_code
                FROM post_consign_item
                WHERE inspect_inspect_code = %s
                FOR UPDATE
                """, (item["inspect_code"],),
            )
            _require(c.fetchone() is None, "이미 대리판매 등록된 검수 상품입니다.")
            c.execute(
                """
                SELECT cardinfo_last_sell_seq
                FROM cardinfo
                WHERE cardinfo_serial_code = %s
                FOR UPDATE
                """, (item["inspect_serial_code"],),
            )
            catalog=c.fetchone()
            _require(catalog is not None, "카탈로그 상품을 찾을 수 없습니다.", 404)
            seq=catalog["cardinfo_last_sell_seq"]+1
            _require(seq <= 18446744073709551615, "판매 순번의 최대값을 초과했습니다.")
            product_code=f"{item['inspect_serial_code']}-{seq}"
            _require(len(product_code) <= 24, "현재 구매코드 길이 제한상 상품 코드는 24자 이하여야 합니다.")
            c.execute(
                """
                UPDATE cardinfo
                SET cardinfo_last_sell_seq = %s
                WHERE cardinfo_serial_code = %s
                """, (seq, item["inspect_serial_code"]),
            )
            product=SellProductResponse(sell_product_code=product_code, sell_product_serial_code=item["inspect_serial_code"],
                seq=seq, sell_product_title=request.sell_product_title, sell_product_image=request.sell_product_image,
                sell_product_contents=request.sell_product_contents, sell_product_sell_price=request.sell_product_sell_price,
                sell_product_grade=item["inspect_grade"], sell_product_sell_status="판매중")
            c.execute(
                """
                INSERT INTO sell_product (
                    sell_product_code, sell_product_serial_code, seq, sell_product_title,
                    sell_product_image, sell_product_contents, sell_product_sell_price,
                    sell_product_grade, sell_product_sell_status
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (product_code, product.sell_product_serial_code, seq, product.sell_product_title,
                      product.sell_product_image, product.sell_product_contents, product.sell_product_sell_price,
                      product.sell_product_grade, "판매중"),
            )
            result=ConsignCreateResponse(post_consign_item_code="CON_"+uuid4().hex,
                manager_manager_id=manager_id, post_consign_item_date=_now(), post_consign_item_complete_date=None,
                post_consign_item_intention="대리판매", inspect_inspect_code=item["inspect_code"],
                sell_product_sell_product_code=product_code, user_user_id=item["user_user_id"], sell_product=product)
            c.execute(
                """
                INSERT INTO post_consign_item (
                    post_consign_item_code, manager_manager_id, post_consign_item_date,
                    post_consign_item_intention, inspect_inspect_code, sell_product_sell_product_code
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """, (result.post_consign_item_code, manager_id, result.post_consign_item_date,
                      "대리판매", item["inspect_code"], product_code),
            )
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 대리판매 등록된 검수 상품입니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise
    return result


def get_consigns(db, current, code=None):
    query = """
        SELECT pci.*, ir.user_user_id
        FROM post_consign_item pci
        JOIN inspect i ON i.inspect_code = pci.inspect_inspect_code
        JOIN inspection_request ir ON ir.inspection_request_no = i.inspect_requested_no
        WHERE 1 = 1
    """
    params=[]
    if code is not None:
        query += "\n AND pci.post_consign_item_code = %s"
        params.append(code)
    if current.role != "manager":
        query += "\n AND ir.user_user_id = %s"
        params.append(current.account.user_id)
    query += "\n ORDER BY pci.post_consign_item_date DESC, pci.post_consign_item_code DESC"
    with db.cursor() as c:
        c.execute(query, tuple(params))
        rows=c.fetchall()
    if code is not None:
        _require(bool(rows), "대리판매 등록을 찾을 수 없거나 조회 권한이 없습니다.", 404)
        _require(len(rows)==1, "중복된 대리판매 등록 코드를 확인해주세요.")
        return ConsignResponse(**rows[0])
    return [ConsignResponse(**r) for r in rows]
