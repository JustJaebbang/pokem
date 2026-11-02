import tempfile
import unittest
from io import BytesIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient
from PIL import Image

from database import get_db
from dependencies import get_current_account
from routers.product_image import router
from services import product_image_service


def image_bytes(image_format="PNG"):
    output = BytesIO()
    image = Image.new("RGB", (8, 6), "red")
    if image_format == "JPEG":
        exif = Image.Exif()
        exif[270] = "private metadata"
        image.save(output, format=image_format, exif=exif)
    else:
        image.save(output, format=image_format)
    return output.getvalue()


class FakeCursor:
    def __init__(self, database):
        self.database = database
        self.row = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        return False

    def execute(self, sql, params):
        if "INSERT INTO product_image" in sql:
            image_id, extension, mime, data, size, created_at = params
            self.database.images[image_id] = {
                "product_image_extension": extension,
                "product_image_mime": mime,
                "product_image_data": data,
                "product_image_size": size,
                "product_image_created_at": created_at,
            }
            return
        if "FROM product_image" in sql:
            self.row = self.database.images.get(params[0])
            return
        raise AssertionError(f"Unexpected SQL: {sql}")

    def fetchone(self):
        return self.row


class FakeImageDatabase:
    def __init__(self):
        self.images = {}
        self.commits = 0
        self.rollbacks = 0

    def cursor(self):
        return FakeCursor(self)

    def commit(self):
        self.commits += 1

    def rollback(self):
        self.rollbacks += 1


class ProductImageTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.folder = Path(temp.name) / "products"
        directory = patch.object(product_image_service, "IMAGE_DIRECTORY", self.folder)
        directory.start()
        self.addCleanup(directory.stop)

        self.database = FakeImageDatabase()
        self.app = FastAPI()
        self.app.include_router(router)
        self.app.dependency_overrides[get_db] = lambda: self.database
        self.app.dependency_overrides[get_current_account] = lambda: SimpleNamespace(role="user")
        self.client = TestClient(self.app)
        self.addCleanup(self.client.close)

    def upload(self, data, filename="photo.png", content_type="image/png"):
        return self.client.post(
            "/sell_product/image",
            files={"file": (filename, data, content_type)},
        )

    def test_supported_images_are_stored_as_blob_and_publicly_downloaded(self):
        for image_format in ("JPEG", "PNG", "WEBP"):
            with self.subTest(image_format=image_format):
                response = self.upload(image_bytes(image_format))
                self.assertEqual(response.status_code, 201, response.text)
                url = response.json()["sell_product_image"]
                self.assertRegex(url, r"^/media/products/[0-9a-f]{32}\.(jpg|png|webp)$")
                self.assertEqual(set(response.json()), {"sell_product_image"})

                image_id = url.rsplit("/", 1)[1].split(".", 1)[0]
                stored = self.database.images[image_id]
                self.assertEqual(stored["product_image_size"], len(stored["product_image_data"]))
                self.assertFalse(self.folder.exists())

                downloaded = self.client.get(url)
                self.assertEqual(downloaded.status_code, 200)
                self.assertEqual(downloaded.headers["x-content-type-options"], "nosniff")
                with Image.open(BytesIO(downloaded.content)) as image:
                    self.assertEqual(image.format, image_format)
                    self.assertEqual(image.size, (8, 6))
                    self.assertFalse(image.getexif())

        self.assertEqual(self.database.commits, 3)

    def test_invalid_content_and_unsupported_format_are_rejected(self):
        for data in (b"<script>not an image</script>", image_bytes()[:25], image_bytes("GIF")):
            with self.subTest(length=len(data)):
                self.assertEqual(self.upload(data).status_code, 415)
        self.assertFalse(self.database.images)

    def test_empty_missing_and_large_files(self):
        self.assertEqual(self.upload(b"").status_code, 422)
        self.assertEqual(self.client.post("/sell_product/image").status_code, 422)
        self.assertEqual(
            self.upload(b"x" * (product_image_service.MAX_IMAGE_BYTES + 1)).status_code,
            413,
        )
        self.assertFalse(self.database.images)

    def test_resolution_limit_and_animation(self):
        with patch.object(product_image_service, "MAX_IMAGE_PIXELS", 10):
            self.assertEqual(self.upload(image_bytes()).status_code, 413)
        output = BytesIO()
        Image.new("RGBA", (2, 2), "red").save(
            output,
            format="PNG",
            save_all=True,
            append_images=[Image.new("RGBA", (2, 2), "blue")],
            duration=100,
            loop=0,
        )
        self.assertEqual(self.upload(output.getvalue()).status_code, 415)

    def test_authentication_is_required_for_upload(self):
        self.app.dependency_overrides.pop(get_current_account)
        self.assertEqual(self.upload(image_bytes()).status_code, 401)
        self.assertFalse(self.database.images)

    def test_filename_is_generated_and_missing_files_are_404(self):
        response = self.upload(
            image_bytes(),
            filename="../../security.py",
            content_type="text/plain",
        )
        self.assertEqual(response.status_code, 201, response.text)
        self.assertEqual(len(self.database.images), 1)
        self.assertEqual(self.client.get("/media/products/security.py").status_code, 404)
        self.assertEqual(
            self.client.get("/media/products/" + "0" * 32 + ".png").status_code,
            404,
        )

    def test_legacy_disk_image_remains_available(self):
        filename = "a" * 32 + ".png"
        self.folder.mkdir(parents=True)
        (self.folder / filename).write_bytes(image_bytes())

        response = self.client.get(f"/media/products/{filename}")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers["content-type"], "image/png")

    def test_uploaded_image_is_public_and_unique(self):
        first = self.upload(image_bytes()).json()["sell_product_image"]
        second = self.upload(image_bytes()).json()["sell_product_image"]
        self.assertNotEqual(first, second)
        self.app.dependency_overrides.pop(get_current_account)
        self.assertEqual(self.client.get(first).status_code, 200)


if __name__ == "__main__":
    unittest.main()
