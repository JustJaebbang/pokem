import re
import warnings
from io import BytesIO
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException
from PIL import Image, ImageOps, UnidentifiedImageError

MAX_IMAGE_BYTES = 5 * 1024 * 1024
MAX_IMAGE_PIXELS = 10_000_000
IMAGE_DIRECTORY = Path(__file__).resolve().parents[1] / "uploads" / "products"
FORMATS = {"JPEG": ("jpg", "image/jpeg"), "PNG": ("png", "image/png"), "WEBP": ("webp", "image/webp")}
IMAGE_NAME = re.compile(r"[0-9a-f]{32}\.(jpg|png|webp)")


def save_product_image(file):
    # 원본 파일명·확장자 대신 실제 디코딩 결과를 검증한다.
    data = file.read(MAX_IMAGE_BYTES + 1)
    if not data:
        raise HTTPException(status_code=422, detail="이미지 파일이 비어 있습니다.")
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="이미지는 5MB 이하여야 합니다.")
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(BytesIO(data)) as original:
                if original.format not in FORMATS:
                    raise HTTPException(status_code=415, detail="JPEG, PNG, WebP 이미지만 지원합니다.")
                if original.width * original.height > MAX_IMAGE_PIXELS:
                    raise HTTPException(status_code=413, detail="이미지는 1,000만 픽셀 이하여야 합니다.")
                if getattr(original, "is_animated", False):
                    raise HTTPException(status_code=415, detail="정지 이미지 한 장만 지원합니다.")
                image_format = original.format
                original.load()
                oriented = ImageOps.exif_transpose(original)
                mode = "RGB" if image_format == "JPEG" else "RGBA"
                # 새 캔버스에 복사하여 EXIF 위치정보 등 원본 메타데이터를 저장하지 않는다.
                converted = oriented.convert(mode)
                clean = Image.new(mode, converted.size)
                clean.paste(converted)
                output = BytesIO()
                clean.save(output, format=image_format)
    except (Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise HTTPException(status_code=413, detail="이미지 해상도가 너무 큽니다.") from exc
    except (UnidentifiedImageError, OSError, ValueError, SyntaxError) as exc:
        raise HTTPException(status_code=415, detail="정상적인 이미지 파일을 업로드해주세요.") from exc
    if output.tell() > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="변환한 이미지가 5MB를 초과합니다.")
    extension, _ = FORMATS[image_format]
    filename = f"{uuid4().hex}.{extension}"
    IMAGE_DIRECTORY.mkdir(parents=True, exist_ok=True)
    target = IMAGE_DIRECTORY / filename
    created = False
    try:
        with target.open("xb") as destination:
            created = True
            destination.write(output.getbuffer())
    except Exception:
        # 이번 요청이 생성한 부분 파일만 정리한다.
        if created:
            target.unlink(missing_ok=True)
        raise
    return f"/media/products/{filename}"


def get_product_image(filename):
    if IMAGE_NAME.fullmatch(filename) is None:
        raise HTTPException(status_code=404, detail="이미지를 찾을 수 없습니다.")
    root = IMAGE_DIRECTORY.resolve()
    target = (root / filename).resolve()
    if target.parent != root or not target.is_file():
        raise HTTPException(status_code=404, detail="이미지를 찾을 수 없습니다.")
    media_type = next(mime for extension, mime in FORMATS.values() if target.suffix == '.' + extension)
    return target, media_type
