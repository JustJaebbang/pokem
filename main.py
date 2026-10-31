# -*- coding: utf-8 -*-

from fastapi import FastAPI, Request
import asyncio
from contextlib import asynccontextmanager
from services.consignment_expiry_worker import expiry_worker
from pydantic import BaseModel
import joblib

from routers.wallet_ledger import router as wallet_ledger_router
from routers.pending_actions import router as pending_actions_router
from routers.notification import router as notification_router
from routers.user import router as user_router
from routers.sell_product import router as sell_product_router
from routers.product_image import router as product_image_router
from routers.sale_history import router as sale_history_router
from routers.post_item import router as post_item_router
from routers.wishlist import router as wishlist_router
from routers.purchase_item import router as purchase_item_router
from routers.recharge import router as recharge_router
from routers.exchange import router as exchange_router
from routers.review import router as review_router
from routers.purchase_cancel import router as purchase_cancel_router
from routers.chat_room import router as chat_room_router
from routers.chat_socket import router as chat_socket_router
from routers.inspect import router as inspect_router
from routers.return_item import router as return_router
from routers.post_consign_item import router as post_consign_item_router
from routers.manager import router as manager_router
from routers.auth import router as auth_router
from routers.cybermoney_pay import router as cybermoney_pay_router
from routers.inspection_request import router as inspection_request_router
from routers.pay import router as pay_router
from routers.deposit_refund import router as deposit_refund_router
from routers.delivery import router as delivery_router
from routers.director import router as director_router
from routers.case import router as case_router
from routers.delivery_company import router as delivery_company_router
from routers.product_company import router as product_company_router
from routers.proposal import router as proposal_router
from routers.order import router as order_router
from routers.receive import router as receive_router
from routers.receipt import router as receipt_router
from routers.discard import router as discard_router

@asynccontextmanager
async def lifespan(app):
    stop = asyncio.Event()
    task = asyncio.create_task(expiry_worker(stop))
    try:
        yield
    finally:
        stop.set()
        await task


app = FastAPI(lifespan=lifespan)

app.include_router(user_router)
app.include_router(notification_router)
app.include_router(pending_actions_router)
app.include_router(wallet_ledger_router)
app.include_router(product_image_router)
app.include_router(sell_product_router)
app.include_router(post_item_router)
app.include_router(sale_history_router)
app.include_router(wishlist_router)
app.include_router(purchase_item_router)
app.include_router(recharge_router)
app.include_router(exchange_router)
app.include_router(review_router)
app.include_router(purchase_cancel_router)
app.include_router(chat_room_router)
app.include_router(chat_socket_router)
app.include_router(inspect_router)
app.include_router(return_router)
app.include_router(post_consign_item_router)
app.include_router(manager_router)
app.include_router(auth_router)
app.include_router(cybermoney_pay_router)
app.include_router(inspection_request_router)
app.include_router(pay_router)
app.include_router(deposit_refund_router)
app.include_router(delivery_router)
app.include_router(director_router)
app.include_router(case_router)
app.include_router(delivery_company_router)
app.include_router(product_company_router)
app.include_router(proposal_router)
app.include_router(order_router)
app.include_router(receive_router)
app.include_router(receipt_router)
app.include_router(discard_router)

@app.get("/")
def root():
    return {"status": "success", "message": "Pokem API 너로 정했다!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app, 
        # 에뮬레이터와 같은 Wi-Fi의 실제 기기에서 모두 접속할 수 있게 대기합니다.
        host="0.0.0.0",
        port=8000
    )
