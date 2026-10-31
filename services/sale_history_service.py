from datetime import datetime, timedelta, timezone
from schemas.sale_history import SaleHistoryResponse


def _timestamp(value):
    if value is None:
        return None
    parsed = datetime.fromisoformat(str(value))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone(timedelta(hours=9)))
    return parsed.isoformat(timespec='seconds')


def get_sale_history(db, user_id):
    with db.cursor() as cursor:
        cursor.execute('''
            SELECT r.*, sp.sell_product_title AS title, sp.sell_product_image AS image,
                sp.sell_product_sell_status AS status, sp.sell_product_sell_price AS asking_price,
                (
                    SELECT CASE WHEN COUNT(*) = 1 THEN MAX(cp.cybermoney_pay_price) END
                    FROM purchase_item pi
                    JOIN cybermoney_pay cp ON cp.purchase_item_purchase_item_code = pi.purchase_item_code
                    WHERE pi.sell_product_sell_product_code = r.product_code
                        AND pi.purchase_item_status <> '거래취소'
                ) AS paid_price
            FROM (
                SELECT post_item_code AS sale_code, 'direct' AS sale_type,
                    sell_product_sell_product_code AS product_code,
                    post_item_post_date AS posted_at, post_item_complete_date AS completed_at
                FROM post_item WHERE user_user_id = %s
                UNION ALL
                SELECT pci.post_consign_item_code AS sale_code, 'consign' AS sale_type,
                    pci.sell_product_sell_product_code AS product_code,
                    pci.post_consign_item_date AS posted_at, pci.post_consign_item_complete_date AS completed_at
                FROM post_consign_item pci
                JOIN inspect i ON i.inspect_code = pci.inspect_inspect_code
                JOIN inspection_request ir ON ir.inspection_request_no = i.inspect_requested_no
                WHERE ir.user_user_id = %s
            ) r
            LEFT JOIN sell_product sp ON sp.sell_product_code = r.product_code
            ORDER BY COALESCE(r.completed_at, r.posted_at) DESC, r.sale_code DESC
        ''', (user_id, user_id))
        rows = cursor.fetchall()
    for row in rows:
        row['posted_at'] = _timestamp(row['posted_at'])
        row['completed_at'] = _timestamp(row['completed_at'])
    records = [SaleHistoryResponse(**row) for row in rows]
    # 일반판매의 공백 구분 일시와 대리판매 ISO 일시를 같은 시간 기준으로 정렬합니다.
    return sorted(records, key=lambda item: datetime.fromisoformat(
        item.completed_at or item.posted_at).timestamp() if item.completed_at or item.posted_at else float('-inf'), reverse=True)
