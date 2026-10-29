"""상품 행 잠금 아래에서 일반판매/대리판매의 실제 소유자를 확인합니다."""


def get_sale_registrations(cursor, product_code):
    # 소유자 관계를 변경하는 API도 먼저 해당 상품 행을 잠가야 합니다.
    cursor.execute(
        """
        SELECT post_item_code, user_user_id, post_item_complete_date,
               'direct' AS registration_type
        FROM post_item
        WHERE sell_product_sell_product_code = %s
        UNION ALL
        SELECT pci.post_consign_item_code AS post_item_code,
               ir.user_user_id,
               pci.post_consign_item_complete_date AS post_item_complete_date,
               'consign' AS registration_type
        FROM post_consign_item pci
        JOIN inspect i ON i.inspect_code = pci.inspect_inspect_code
        JOIN inspection_request ir ON ir.inspection_request_no = i.inspect_requested_no
        WHERE pci.sell_product_sell_product_code = %s
        """, (product_code, product_code),
    )
    return cursor.fetchall()


def complete_sale_registration(cursor, post, product_code, timestamp):
    if post.get("registration_type", "direct") == "consign":
        cursor.execute(
            """
            UPDATE post_consign_item
            SET post_consign_item_complete_date = %s
            WHERE sell_product_sell_product_code = %s
                AND post_consign_item_complete_date IS NULL
            """, (timestamp, product_code),
        )
    else:
        cursor.execute(
            """
            UPDATE post_item
            SET post_item_complete_date = %s
            WHERE post_item_code = %s
                AND post_item_complete_date IS NULL
            """, (timestamp, post["post_item_code"]),
        )
