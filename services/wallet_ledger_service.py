from datetime import datetime, timedelta, timezone
from schemas.wallet_ledger import WalletLedgerResponse

# Each branch selects only this user's actual balance movements. Cancellation
# does not erase the original debit; the refund record supplies the credit.
LEDGER_SQL = """
SELECT * FROM (
 SELECT CONCAT('recharge:', recharge_seq) AS event_id, 'recharge' AS kind,
        recharge_price AS amount, recharge_date AS occurred_at,
        user_user_id, CAST(recharge_seq AS CHAR) AS source_code,
        NULL AS payment_code, NULL AS purchase_code, NULL AS product_code, NULL AS product_title
 FROM recharge WHERE user_user_id = %s
 UNION ALL
 SELECT CONCAT('exchange:', exchange_seq), 'exchange', -exchange_price,
        exchange_date, user_id, CAST(exchange_seq AS CHAR), NULL, NULL, NULL, NULL
 FROM exchange WHERE user_id = %s
 UNION ALL
 SELECT CONCAT('payment:', cp.cybermoney_pay_code), 'payment', -cp.cybermoney_pay_price,
        cp.cybermoney_pay_date, pi.user_user_id, cp.cybermoney_pay_code,
        cp.cybermoney_pay_code, pi.purchase_item_code, pi.sell_product_sell_product_code, sp.sell_product_title
 FROM cybermoney_pay cp
 JOIN purchase_item pi ON pi.purchase_item_code = cp.purchase_item_purchase_item_code
 LEFT JOIN sell_product sp ON sp.sell_product_code = pi.sell_product_sell_product_code
 WHERE pi.user_user_id = %s AND cp.cybermoney_pay_status IN ('결제완료', '결제취소')
 UNION ALL
 SELECT CONCAT('refund:', rc.cybermoney_pay_cancel_code), 'refund', rc.cybermoney_pay_cancel_price,
        rc.cybermoney_pay_cancel_date, rc.user_user_id, rc.cybermoney_pay_cancel_code,
        cp.cybermoney_pay_code, cp.purchase_item_purchase_item_code, pi.sell_product_sell_product_code, sp.sell_product_title
 FROM cybermoney_pay_cancel rc
 LEFT JOIN cybermoney_pay cp ON cp.cybermoney_pay_code = rc.cybermoney_pay_cybermoney_pay_code
 LEFT JOIN purchase_item pi ON pi.purchase_item_code = cp.purchase_item_purchase_item_code
 LEFT JOIN sell_product sp ON sp.sell_product_code = pi.sell_product_sell_product_code
 WHERE rc.user_user_id = %s
 UNION ALL
 SELECT CONCAT('sale_credit:', cg.cybermoney_give_code), 'sale_credit', cg.cybermoney_give_price,
        cg.cybermoney_give_date, %s, cg.cybermoney_give_code,
        cp.cybermoney_pay_code, pi.purchase_item_code, pi.sell_product_sell_product_code, sp.sell_product_title
 FROM cybermoney_give cg
 JOIN cybermoney_pay cp ON cp.cybermoney_pay_code = cg.cybermoney_pay_code
 JOIN purchase_item pi ON pi.purchase_item_code = cp.purchase_item_purchase_item_code
 LEFT JOIN sell_product sp ON sp.sell_product_code = pi.sell_product_sell_product_code
 WHERE cg.cybermoney_give_status = '지급완료' AND (
   EXISTS (SELECT 1 FROM post_item po
     WHERE po.sell_product_sell_product_code = pi.sell_product_sell_product_code AND po.user_user_id = %s)
   OR EXISTS (SELECT 1 FROM post_consign_item pci
     JOIN inspect i ON i.inspect_code = pci.inspect_inspect_code
     JOIN inspection_request ir ON ir.inspection_request_no = i.inspect_requested_no
     WHERE pci.sell_product_sell_product_code = pi.sell_product_sell_product_code AND ir.user_user_id = %s)
 )
) movements
"""

def get_wallet_ledger(db, user_id, limit=30, offset=0, direction=None):
    query = LEDGER_SQL
    if direction == "in":
        query += " WHERE amount > 0"
    elif direction == "out":
        query += " WHERE amount < 0"
    # These five writers record Korean local time (+09:00 or legacy naive).
    # Normalize the separator for ordering before pagination, including old rows.
    query += " ORDER BY REPLACE(SUBSTRING(occurred_at, 1, 19), 'T', ' ') DESC, event_id DESC LIMIT %s OFFSET %s"
    with db.cursor() as cursor:
        cursor.execute(query, (user_id,) * 7 + (limit, offset))
        rows = cursor.fetchall()
    for row in rows:
        value = row["occurred_at"]
        if value is not None:
            parsed = value if isinstance(value, datetime) else datetime.fromisoformat(str(value))
            if parsed.tzinfo is None:
                parsed = parsed.replace(tzinfo=timezone(timedelta(hours=9)))
            row["occurred_at"] = parsed.isoformat(timespec="seconds")
    return [WalletLedgerResponse(**row) for row in rows]
