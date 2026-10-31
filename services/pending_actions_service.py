from schemas.pending_actions import PendingActionsResponse

def get_pending_actions(db, user_id):
    with db.cursor() as cursor:
        cursor.execute("""
            SELECT COUNT(*) AS count, MIN(inspection_request_inspection_request_no) AS request_no
            FROM pay
            WHERE user_user_id = %s AND pay_status = '결제대기' AND pay_price >= 0
        """, (user_id,))
        fees = cursor.fetchone()
        cursor.execute("""
            SELECT COUNT(*) AS count, MIN(i.inspect_requested_no) AS request_no
            FROM inspect i
            JOIN inspection_request ir ON ir.inspection_request_no = i.inspect_requested_no
            WHERE ir.user_user_id = %s AND i.inspect_status = '검수완료'
              AND i.inspect_user_choice = '의사확인대기'
        """, (user_id,))
        choices = cursor.fetchone()
        cursor.execute("""
            SELECT COUNT(*) AS count
            FROM purchase_cancel pc
            JOIN purchase_item pi ON pi.purchase_item_code = pc.purchase_item_purchase_item_code
            WHERE pc.purchase_cancel_status = '요청중' AND pi.purchase_item_status = '취소요청'
              AND (
                EXISTS (SELECT 1 FROM post_item po
                  WHERE po.sell_product_sell_product_code = pi.sell_product_sell_product_code AND po.user_user_id = %s)
                OR EXISTS (SELECT 1 FROM post_consign_item pci
                  JOIN inspect i ON i.inspect_code = pci.inspect_inspect_code
                  JOIN inspection_request ir ON ir.inspection_request_no = i.inspect_requested_no
                  WHERE pci.sell_product_sell_product_code = pi.sell_product_sell_product_code AND ir.user_user_id = %s)
              )
        """, (user_id, user_id))
        cancellations = cursor.fetchone()
    return PendingActionsResponse(fee_count=fees['count'], fee_request_no=fees['request_no'],
        choice_count=choices['count'], choice_request_no=choices['request_no'], cancel_count=cancellations['count'])
