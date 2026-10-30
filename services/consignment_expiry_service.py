"""만료된 미판매 위탁품을 반환 접수하고 배송준비 건을 원자적으로 생성한다."""
import logging
from datetime import datetime, timedelta, timezone

from schemas.delivery import DeliveryCreate
from services.delivery_service import create_delivery
from services.inspection_common import _inspect_row, _require
from services.return_service import ensure_return

logger = logging.getLogger(__name__)
KST = timezone(timedelta(hours=9))


def expire_consignment(db, code, *, now=None):
    now = (now or datetime.now(KST)).astimezone(KST).replace(tzinfo=None)
    try:
        db.begin()
        with db.cursor() as c:
            c.execute('SELECT sell_product_sell_product_code FROM post_consign_item WHERE post_consign_item_code=%s', (code,))
            source = c.fetchone()
            if source is None:
                db.rollback()
                return None
            # 구매와 동일하게 상품을 먼저 잠근 뒤 등록 상태를 재확인한다.
            c.execute('SELECT sell_product_sell_status FROM sell_product WHERE sell_product_code=%s FOR UPDATE',
                      (source['sell_product_sell_product_code'],))
            product = c.fetchone()
            c.execute('SELECT * FROM post_consign_item WHERE post_consign_item_code=%s FOR UPDATE', (code,))
            item = c.fetchone()
            if (not product or product['sell_product_sell_status'] != '판매중'
                    or item['post_consign_item_complete_date'] is not None
                    or item['post_consign_item_intention'] != '대리판매'
                    or item['post_consign_item_expires_at'] is None
                    or item['post_consign_item_expires_at'] > now):
                db.rollback()
                return None
            c.execute('SELECT purchase_item_code FROM purchase_item WHERE sell_product_sell_product_code=%s AND purchase_item_status<>%s FOR UPDATE',
                      (source['sell_product_sell_product_code'], '거래취소'))
            _require(c.fetchone() is None, '구매 진행 중인 물품은 반환할 수 없습니다.')
            company = item['return_delivery_company_code']
            _require(bool(company), '반환 배송업체를 지정해주세요.')
            inspect = _inspect_row(c, item['inspect_inspect_code'], lock=True)
            _require(inspect['inspect_user_choice'] == '대리판매', '검수 물품의 대리판매 선택을 확인해주세요.')
            c.execute('UPDATE inspect SET inspect_user_choice=%s, inspect_user_choice_at=%s WHERE inspect_code=%s',
                      ('반환', now.isoformat(timespec='seconds') + '+09:00', inspect['inspect_code']))
            inspect['inspect_user_choice'] = '반환'
            ensure_return(c, inspect)
            c.execute('SELECT return_no FROM `return` WHERE inspect_inspect_code=%s FOR UPDATE', (inspect['inspect_code'],))
            return_no = c.fetchone()['return_no']
            c.execute('UPDATE `return` SET manager_manager_id=%s WHERE return_no=%s', (item['manager_manager_id'], return_no))
            c.execute('UPDATE sell_product SET sell_product_sell_status=%s WHERE sell_product_code=%s',
                      ('반환대기', source['sell_product_sell_product_code']))
            c.execute('UPDATE post_consign_item SET post_consign_item_intention=%s WHERE post_consign_item_code=%s', ('반환', code))
        delivery = create_delivery(db, DeliveryCreate(return_no=return_no,
            manager_manager_id=item['manager_manager_id'], delivery_company_delivery_company_code=company),
            manage_transaction=False)
        db.commit()
        return delivery
    except Exception:
        db.rollback()
        raise


def process_expired_consignments(db, *, limit=100):
    # 한 건 실패가 나머지 위탁품 처리를 막지 않도록 건별 트랜잭션을 사용한다.
    now = datetime.now(KST)
    with db.cursor() as c:
        c.execute('''SELECT post_consign_item_code FROM post_consign_item
            WHERE post_consign_item_expires_at<=%s AND post_consign_item_complete_date IS NULL
              AND post_consign_item_intention=%s
              AND EXISTS (SELECT 1 FROM sell_product s
                WHERE s.sell_product_code=post_consign_item.sell_product_sell_product_code
                  AND s.sell_product_sell_status=%s)
            ORDER BY post_consign_item_expires_at LIMIT %s''',
            (now.replace(tzinfo=None), '대리판매', '판매중', limit))
        codes = [r['post_consign_item_code'] for r in c.fetchall()]
    db.rollback()
    results = []
    for code in codes:
        try:
            result = expire_consignment(db, code, now=now)
            if result is not None:
                results.append(result)
        except Exception:
            logger.exception('대리판매 만료 반환 실패: %s', code)
    return results
