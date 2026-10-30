import asyncio
import logging

from database import get_connection
from services.consignment_expiry_service import process_expired_consignments

logger = logging.getLogger(__name__)


def run_once():
    db = get_connection()
    try:
        return process_expired_consignments(db)
    finally:
        db.close()


async def expiry_worker(stop):
    # 시작 시 및 매 분 확인한다. 프로세스 재시작 중 놓친 만료 건도 다시 처리한다.
    while not stop.is_set():
        try:
            await asyncio.to_thread(run_once)
        except Exception:
            logger.exception('대리판매 만료 스캔 실패')
        try:
            await asyncio.wait_for(stop.wait(), timeout=60)
        except asyncio.TimeoutError:
            pass
