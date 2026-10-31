import unittest
from unittest.mock import patch
from pydantic import ValidationError
from test_quit_auth import DB
from schemas.user import UserCreate,UserUpdate
from schemas.auth import LoginRequest
from services import user_service
URL='/media/products/'+'a'*32+'.jpg'
class ProfileImageTests(unittest.TestCase):
    def setUp(self):
        self.db=DB();self.addCleanup(self.db.conn.close)
    def update(self,**extra):
        return user_service.put_user_id(self.db,UserUpdate(user_phone='01012345678',user_email='new@example.com',user_address='address',**extra),'owner')
    def test_omission_preserves_image_for_older_clients(self):
        self.db.conn.execute('UPDATE user SET user_profile_image=?',(URL,));self.db.conn.commit()
        self.assertEqual(self.update().user_profile_image,URL)
    def test_explicit_null_restores_default_and_url_can_be_saved(self):
        self.assertEqual(self.update(user_profile_image=URL).user_profile_image,URL)
        self.assertIsNone(self.update(user_profile_image=None).user_profile_image)
    def test_read_and_login_return_same_image_without_exposing_password(self):
        self.update(user_profile_image=URL)
        with patch('services.user_service.verify_password',return_value=True):
            login=user_service.login_user(self.db,LoginRequest(login_id='owner',password='pw'))
        self.assertEqual(login.account.user_profile_image,URL)
        self.assertEqual(user_service.get_user_id(self.db,'owner').user_profile_image,URL)
        self.assertNotIn('user_password',login.account.model_dump())
    def test_existing_user_without_image_has_null(self):
        self.assertIsNone(user_service.get_user_id(self.db,'owner').user_profile_image)
    def test_invalid_image_sources_are_rejected(self):
        for value in ['javascript:alert(1)','https://example.com/x.jpg','/media/products/../../x.jpg','', 'x'*1001]:
            with self.subTest(value=value),self.assertRaises(ValidationError):
                UserUpdate(user_phone='010',user_email='mail',user_address='address',user_profile_image=value)
    def test_signup_defaults_to_no_image_and_zero_money(self):
        result=user_service.create_user(self.db,UserCreate(user_id='new',user_password='pw',user_nickname='nick',user_name='name',user_phone='010',user_email='mail',user_address='address'))
        self.assertEqual(result.user_money,0);self.assertIsNone(result.user_profile_image)
