# -*- coding: utf-8 -*-

from fastapi import FastAPI, Request
from pydantic import BaseModel
import joblib

from routers.user import router as user_router
from routers.sell_product import router as sell_product_router
from routers.post_item import router as post_item_router
from routers.wishlist import router as wishlist_router
from routers.purchase_item import router as purchase_item_router

app = FastAPI()

app.include_router(user_router)
app.include_router(sell_product_router)
app.include_router(post_item_router)
app.include_router(wishlist_router)
app.include_router(purchase_item_router)

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
