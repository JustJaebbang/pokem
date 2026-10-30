from fastapi import APIRouter, Depends, File, UploadFile
from fastapi.responses import FileResponse

from dependencies import get_current_account
from schemas.product_image import ProductImageResponse
from services import product_image_service

router = APIRouter(tags=["sell_product_image"])


@router.post("/sell_product/image", response_model=ProductImageResponse, status_code=201)
def upload_product_image(file: UploadFile = File(...), current=Depends(get_current_account)):
    try:
        url = product_image_service.save_product_image(file.file)
        return ProductImageResponse(sell_product_image=url)
    finally:
        file.file.close()


@router.get("/media/products/{filename}", response_class=FileResponse)
def get_product_image(filename: str):
    path, media_type = product_image_service.get_product_image(filename)
    return FileResponse(path, media_type=media_type, headers={
        "Cache-Control": "public, max-age=31536000, immutable",
        "X-Content-Type-Options": "nosniff",
    })
