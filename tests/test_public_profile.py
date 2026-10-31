import unittest
from fastapi import HTTPException
from test_quit_auth import DB
from services.public_profile_service import get_public_profile
from services.chat_room_service import get_chat_room,get_chat_room_id
URL='/media/products/'+'a'*32+'.jpg'
class PublicProfileTests(unittest.TestCase):
    def setUp(self):
        self.db=DB();self.addCleanup(self.db.conn.close)
        self.db.conn.executescript("""
          ALTER TABLE chat_room ADD COLUMN chat_room_name TEXT;
          ALTER TABLE chat_room ADD COLUMN chat_room_status TEXT;
          ALTER TABLE chat_room ADD COLUMN chat_room_date TEXT;
          ALTER TABLE chat_room ADD COLUMN sell_product_sell_product_code TEXT;
          UPDATE chat_room SET chat_room_name='카드 문의',chat_room_status='대화중',chat_room_date='2026-10-31',sell_product_sell_product_code='P1';
          INSERT INTO user(user_id,user_password,user_nickname,user_name,user_phone,user_email,user_address,user_money) VALUES('seller','hash','판매자 닉네임','실명','010','private-mail','private-address',12345);
        """)
        self.db.conn.execute('UPDATE user SET user_profile_image=? WHERE user_id=?',(URL,'seller'));self.db.conn.commit()
    def test_public_profile_is_an_explicit_safe_field_allowlist(self):
        profile=get_public_profile(self.db,'seller')
        self.assertEqual(profile.user_nickname,'판매자 닉네임');self.assertEqual(profile.user_profile_image,URL)
        self.assertEqual(set(profile.model_dump()),{'user_id','user_nickname','user_profile_image','is_withdrawn'})
        self.assertNotIn('private-mail',str(profile.model_dump()))
        self.assertIsNone(get_public_profile(self.db,'missing'))
    def test_retired_user_retains_record_but_public_name_and_image_are_masked(self):
        self.db.conn.execute("INSERT INTO quit VALUES('seller','2026-10-31','reason')")
        profile=get_public_profile(self.db,'seller')
        self.assertTrue(profile.is_withdrawn);self.assertEqual(profile.user_nickname,'탈퇴한 사용자');self.assertIsNone(profile.user_profile_image)
        self.assertEqual(self.db.conn.execute("SELECT user_profile_image FROM user WHERE user_id='seller'").fetchone()[0],URL)
    def test_room_list_returns_opposite_profile_for_each_participant(self):
        buyer=get_chat_room(self.db,'owner')[0]
        seller=get_chat_room(self.db,'seller')[0]
        self.assertEqual(buyer.other_user_nickname,'판매자 닉네임');self.assertEqual(buyer.other_user_profile_image,URL)
        self.assertEqual(seller.other_user_nickname,'nickname');self.assertIsNone(seller.other_user_profile_image)
        self.assertEqual(get_chat_room(self.db,'intruder'),[])
    def test_detail_preserves_participant_authorization(self):
        detail=get_chat_room_id(self.db,'ROOM','owner')
        self.assertEqual(detail.other_user_profile_image,URL)
        with self.assertRaises(HTTPException) as e:get_chat_room_id(self.db,'ROOM','intruder')
        self.assertEqual(e.exception.status_code,403)
        with self.assertRaises(HTTPException) as e:get_chat_room_id(self.db,'missing','owner')
        self.assertEqual(e.exception.status_code,404)
    def test_chat_retired_profile_is_masked_without_dropping_room(self):
        self.db.conn.execute("INSERT INTO quit VALUES('seller','2026-10-31','reason')")
        room=get_chat_room(self.db,'owner')[0]
        self.assertTrue(room.other_user_withdrawn);self.assertEqual(room.other_user_nickname,'탈퇴한 사용자');self.assertIsNone(room.other_user_profile_image)
