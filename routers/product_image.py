from fastapi import APIRouter, Depends, File, UploadFile
from fastapi.responses import Response

from database import get_db
from dependencies import get_current_account
from schemas.product_image import ProductImageResponse
from services import product_image_service

router = APIRouter(tags=["sell_product_image"])


@router.post("/sell_product/image", response_model=ProductImageResponse, status_code=201)
def upload_product_image(
    file: UploadFile = File(...),
    current=Depends(get_current_account),
    db=Depends(get_db),
):
    try:
        url = product_image_service.save_product_image(db, file.file)
        return ProductImageResponse(sell_product_image=url)
    finally:
        file.file.close()


@router.get("/media/products/{filename}", response_class=Response)
def get_product_image(filename: str, db=Depends(get_db)):
    image_data, media_type = product_image_service.get_product_image(db, filename)
    return Response(content=image_data, media_type=media_type, headers={
        "Cache-Control": "public, max-age=31536000, immutable",
        "X-Content-Type-Options": "nosniff",
    })
