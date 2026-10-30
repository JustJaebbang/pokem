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


class ProductImageTests(unittest.TestCase):
    def setUp(self):
        directory=tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.folder=Path(directory.name)/'products'
        location=patch.object(product_image_service,'IMAGE_DIRECTORY',self.folder)
        location.start()
        self.addCleanup(location.stop)
        self.app=FastAPI()
        self.app.include_router(router)
        self.app.dependency_overrides[get_db]=lambda:None
        self.app.dependency_overrides[get_current_account]=lambda:SimpleNamespace(role='user')
        self.client=TestClient(self.app)
        self.addCleanup(self.client.close)

    def image(self,format='PNG'):
        result=BytesIO()
        image=Image.new('RGB',(4,4),'red')
        exif=Image.Exif()
        exif[270]='private'
        image.save(result,format=format,exif=exif)
        return result.getvalue()

    def upload(self,data,name='photo.png'):
        return self.client.post('/sell_product/image',files={'file':(name,data,'image/png')})

    def test_upload_formats_public_view_and_metadata_removal(self):
        for format in ('PNG','JPEG','WEBP'):
            result=self.upload(self.image(format),'../../security.py')
            self.assertEqual(result.status_code,201,result.text)
            url=result.json()['sell_product_image']
            self.assertRegex(url,r'^/media/products/[0-9a-f]{32}\.(jpg|png|webp)$')
            image=self.client.get(url)
            self.assertEqual(image.status_code,200)
            with Image.open(BytesIO(image.content)) as decoded:
                self.assertFalse(decoded.getexif())
                self.assertEqual(decoded.format,format)

    def test_empty_fake_and_large_files(self):
        self.assertEqual(self.upload(b'').status_code,422)
        self.assertEqual(self.upload(b'not an image').status_code,415)
        self.assertEqual(self.upload(b'x'*(5*1024*1024+1)).status_code,413)
        with patch.object(product_image_service,'MAX_IMAGE_PIXELS',2):
            self.assertEqual(self.upload(self.image()).status_code,413)
        self.assertFalse(self.folder.exists())

    def test_authentication_and_missing_file(self):
        self.app.dependency_overrides.pop(get_current_account)
        self.assertEqual(self.upload(self.image()).status_code,401)
        self.assertEqual(self.client.get('/media/products/security.py').status_code,404)
        self.assertEqual(self.client.get('/media/products/'+'0'*32+'.png').status_code,404)
