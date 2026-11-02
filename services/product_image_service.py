import re
import warnings
from datetime import datetime
from io import BytesIO
from pathlib import Path
from uuid import uuid4
from zoneinfo import ZoneInfo

from fastapi import HTTPException
from PIL import Image, ImageOps, UnidentifiedImageError

MAX_IMAGE_BYTES = 5 * 1024 * 1024
MAX_IMAGE_PIXELS = 10_000_000
IMAGE_DIRECTORY = Path(__file__).resolve().parents[1] / "uploads" / "products"
FORMATS = {
    "JPEG": ("jpg", "image/jpeg"),
    "PNG": ("png", "image/png"),
    "WEBP": ("webp", "image/webp"),
}
IMAGE_NAME = re.compile(r"(?P<image_id>[0-9a-f]{32})\.(?P<extension>jpg|png|webp)")


def _normalize_image(file) -> tuple[bytes, str, str]:
    """업로드 파일을 검증하고 EXIF 등 불필요한 메타데이터를 제거한다."""
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
                    raise HTTPException(
                        status_code=415,
                        detail="JPEG, PNG, WebP 이미지만 지원합니다.",
                    )
                if original.width * original.height > MAX_IMAGE_PIXELS:
                    raise HTTPException(
                        status_code=413,
                        detail="이미지는 1,000만 픽셀 이하여야 합니다.",
                    )
                if getattr(original, "is_animated", False):
                    raise HTTPException(
                        status_code=415,
                        detail="정적 이미지만 지원합니다.",
                    )

                image_format = original.format
                original.load()
                oriented = ImageOps.exif_transpose(original)
                mode = "RGB" if image_format == "JPEG" else "RGBA"

                # 새 캔버스에 복사해 EXIF와 원본 메타데이터를 BLOB에 남기지 않는다.
                converted = oriented.convert(mode)
                clean = Image.new(mode, converted.size)
                clean.paste(converted)
                output = BytesIO()
                clean.save(output, format=image_format)
    except (Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
        raise HTTPException(status_code=413, detail="이미지 해상도가 너무 큽니다.") from exc
    except (UnidentifiedImageError, OSError, ValueError, SyntaxError) as exc:
        raise HTTPException(
            status_code=415,
            detail="정상적인 이미지 파일을 업로드해주세요.",
        ) from exc

    if output.tell() > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="변환한 이미지가 5MB를 초과합니다.")

    extension, mime_type = FORMATS[image_format]
    return output.getvalue(), extension, mime_type


def save_product_image(db, file) -> str:
    """정제한 이미지 원본을 product_image 테이블의 MEDIUMBLOB에 저장한다."""
    image_data, extension, mime_type = _normalize_image(file)
    image_id = uuid4().hex
    created_at = datetime.now(ZoneInfo("Asia/Seoul")).strftime("%Y-%m-%d %H:%M:%S")

    try:
        with db.cursor() as cursor:
            cursor.execute(
                """INSERT INTO product_image (
                       product_image_id, product_image_extension,
                       product_image_mime, product_image_data,
                       product_image_size, product_image_created_at
                   ) VALUES (%s, %s, %s, %s, %s, %s)""",
                (
                    image_id,
                    extension,
                    mime_type,
                    image_data,
                    len(image_data),
                    created_at,
                ),
            )
        db.commit()
    except Exception:
        db.rollback()
        raise

    # 상품 테이블에는 BLOB 대신 공개 조회 API 경로를 저장한다.
    return f"/media/products/{image_id}.{extension}"


def _get_legacy_file(filename: str) -> tuple[bytes, str]:
    """DB 전환 전에 디스크에 저장한 이미지를 계속 조회할 수 있게 한다."""
    root = IMAGE_DIRECTORY.resolve()
    target = (root / filename).resolve()
    if target.parent != root or not target.is_file():
        raise HTTPException(status_code=404, detail="이미지를 찾을 수 없습니다.")

    extension = target.suffix.removeprefix(".")
    media_type = next(
        mime for saved_extension, mime in FORMATS.values()
        if saved_extension == extension
    )
    return target.read_bytes(), media_type


def get_product_image(db, filename: str) -> tuple[bytes, str]:
    """DB BLOB를 조회하고, 없으면 이전 디스크 저장 파일을 조회한다."""
    match = IMAGE_NAME.fullmatch(filename)
    if match is None:
        raise HTTPException(status_code=404, detail="이미지를 찾을 수 없습니다.")

    with db.cursor() as cursor:
        cursor.execute(
            """SELECT product_image_extension, product_image_mime,
                      product_image_data
                 FROM product_image
                WHERE product_image_id = %s""",
            (match.group("image_id"),),
        )
        row = cursor.fetchone()

    if row is None:
        return _get_legacy_file(filename)

    # URL 확장자와 DB 메타데이터가 다르면 잘못된 경로이므로 노출하지 않는다.
    if row["product_image_extension"] != match.group("extension"):
        raise HTTPException(status_code=404, detail="이미지를 찾을 수 없습니다.")

    return bytes(row["product_image_data"]), row["product_image_mime"]
