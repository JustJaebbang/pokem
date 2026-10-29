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

@app.get("/")
def root():
    return {"status": "success", "message": "Pokem API 너로 정했다!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app, 
        host="192.168.45.218", 
        port=8000
    )
