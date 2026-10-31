from datetime import datetime, timedelta, timezone
from schemas.notification import NotificationResponse
from services.wallet_ledger_service import LEDGER_SQL

NOTIFICATIONS_SQL = """
 SELECT CONCAT('fee:',pay_no) AS id, '검수비 결제가 준비되었습니다' AS title,
        '검수비를 확인하고 결제를 진행해주세요.' AS body, pay_date AS occurred_at,
        'inspection_fee' AS target_type, inspection_request_inspection_request_no AS target_code, user_user_id
 FROM pay WHERE user_user_id=%s AND pay_status='결제대기' AND pay_price>=0
 UNION ALL
 SELECT CONCAT('inspect:',i.inspect_code), '검수가 완료되었습니다',
        '검수 결과를 확인해주세요.', i.inspect_date, 'inspection_result', i.inspect_requested_no, ir.user_user_id
 FROM inspect i JOIN inspection_request ir ON ir.inspection_request_no=i.inspect_requested_no
 WHERE ir.user_user_id=%s AND i.inspect_status='검수완료'
 UNION ALL
 SELECT CONCAT('seller-cancel:',pc.purchase_cancel_code), '구매취소 요청이 도착했습니다',
        '취소 요청을 확인하고 승인 또는 거절해주세요.', pc.purchase_cancel_date,
        'seller_cancel', pc.purchase_cancel_code, %s
 FROM purchase_cancel pc JOIN purchase_item pi ON pi.purchase_item_code=pc.purchase_item_purchase_item_code
 WHERE pc.purchase_cancel_status='요청중' AND pi.purchase_item_status='취소요청' AND (
   EXISTS(SELECT 1 FROM post_item po WHERE po.sell_product_sell_product_code=pi.sell_product_sell_product_code AND po.user_user_id=%s)
   OR EXISTS(SELECT 1 FROM post_consign_item pci JOIN inspect i ON i.inspect_code=pci.inspect_inspect_code
     JOIN inspection_request ir ON ir.inspection_request_no=i.inspect_requested_no
     WHERE pci.sell_product_sell_product_code=pi.sell_product_sell_product_code AND ir.user_user_id=%s))
 UNION ALL
 SELECT CONCAT('buyer-cancel:',pc.purchase_cancel_code,':',pc.purchase_cancel_status),
        CONCAT('구매취소 요청이 ',pc.purchase_cancel_status,'되었습니다'), '구매취소 처리내역을 확인해주세요.',
        pc.responded_at, 'purchase_cancel', pc.purchase_item_purchase_item_code, pc.user_user_id
 FROM purchase_cancel pc WHERE pc.user_user_id=%s AND pc.purchase_cancel_status IN ('승인','거절')
 UNION ALL
 SELECT CONCAT('money:',event_id),
        CASE WHEN kind='refund' THEN '취소 환불이 반영되었습니다' ELSE '판매대금이 입금되었습니다' END,
        '포켐머니 이용내역에서 금액을 확인해주세요.', occurred_at, 'wallet', NULL, user_user_id
 FROM (
""" + LEDGER_SQL + """
 ) credits WHERE kind IN ('refund','sale_credit')
"""

def get_notifications(db,user_id):
    with db.cursor() as cursor:
        cursor.execute(NOTIFICATIONS_SQL,(user_id,)*13)
        rows=cursor.fetchall()
    def timestamp(row):
        value=row['occurred_at']
        if value is None: return float('-inf')
        try:
            parsed=value if isinstance(value,datetime) else datetime.fromisoformat(str(value))
        except ValueError:
            row['occurred_at']=None
            return float('-inf')
        if parsed.tzinfo is None: parsed=parsed.replace(tzinfo=timezone(timedelta(hours=9)))
        row['occurred_at']=parsed.isoformat(timespec='seconds')
        return parsed.timestamp()
    # Existing records are the source of this in-app feed; no duplicate event writes.
    rows.sort(key=lambda row:(timestamp(row),row['id']),reverse=True)
    return [NotificationResponse(**row) for row in rows]
