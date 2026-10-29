# -*- coding: utf-8 -*-

from fastapi import FastAPI, Request
from pydantic import BaseModel
import joblib

from routers.user import router as user_router
from routers.sell_product import router as sell_product_router
from routers.post_item import router as post_item_router
from routers.wishlist import router as wishlist_router
from routers.purchase_item import router as purchase_item_router
from routers.recharge import router as recharge_router
from routers.exchange import router as exchange_router
from routers.review import router as review_router
from routers.purchase_cancel import router as purchase_cancel_router
from routers.chat_room import router as chat_room_router
from routers.chat_socket import router as chat_socket_router
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

app = FastAPI()

app.include_router(user_router)
app.include_router(sell_product_router)
app.include_router(post_item_router)
app.include_router(wishlist_router)
app.include_router(purchase_item_router)
app.include_router(recharge_router)
app.include_router(exchange_router)
app.include_router(review_router)
app.include_router(purchase_cancel_router)
app.include_router(chat_room_router)
app.include_router(chat_socket_router)
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

@app.get("/")
def root():
    return {"status": "success", "message": "Pokem API 너로 정했다!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app, 
        #host="192.168.45.218", // 재영이 ip
        host="192.168.20.42",
        port=8000
    )
