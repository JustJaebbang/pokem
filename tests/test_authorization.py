import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import jwt
from fastapi.testclient import TestClient

from database import get_db
from main import app
from schemas.user import UserResponse
from schemas.manager import ManagerResponse
from schemas.purchase_item import PurchaseItemResponse
from schemas.recharge import RechargeResponse
from schemas.wishlist import WishlistResponse
from security import create_access_token


class AuthorizationTests(unittest.TestCase):
    def setUp(self):
        self.settings = patch.dict(os.environ, {"JWT_SECRET_KEY": "authorization-test-key-" * 3})
        self.settings.start()
        self.addCleanup(self.settings.stop)
        self.db = MagicMock()
        app.dependency_overrides[get_db] = lambda: self.db
        self.addCleanup(app.dependency_overrides.clear)
        self.user = UserResponse(user_id="buyer", user_nickname="nick", user_name="name",
                                 user_phone="010", user_email="test@example.com", user_address="address", user_money=0)
        self.manager = ManagerResponse(manager_id="manager", manager_name="name", manager_phone="010",
                                       manager_email="test@example.com", manager_dept="test")
        self.lookup_user = patch("dependencies.user_service.get_user_id", return_value=self.user).start()
        self.lookup_manager = patch("dependencies.manager_service.get_manager_id", return_value=self.manager).start()
        self.addCleanup(patch.stopall)
        self.client = TestClient(app)
        self.addCleanup(self.client.close)
        token, _ = create_access_token("buyer", "user")
        self.headers = {"Authorization": "Bearer " + token}
        token, _ = create_access_token("manager", "manager")
        self.admin_headers = {"Authorization": "Bearer " + token}

    def test_me_returns_account_and_role(self):
        for headers, role, field, expected in ((self.headers, "user", "user_id", "buyer"),
                                                (self.admin_headers, "manager", "manager_id", "manager")):
            response = self.client.get("/auth/me", headers=headers)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["role"], role)
            self.assertEqual(response.json()["account"][field], expected)
            self.assertNotIn("password", response.text)

    def test_missing_and_invalid_credentials(self):
        for headers in ({}, {"Authorization": "Bearer invalid"}, {"Authorization": "Basic invalid"}):
            response = self.client.get("/auth/me", headers=headers)
            self.assertEqual(response.status_code, 401)
            self.assertEqual(response.headers["WWW-Authenticate"], "Bearer")
        self.lookup_user.assert_not_called()

    def test_expired_and_deleted_accounts(self):
        now = datetime.now(timezone.utc)
        token = jwt.encode(dict(sub="buyer", role="user", token_type="access", iat=now-timedelta(hours=2),
                                exp=now-timedelta(hours=1), iss="pokem-api", aud="pokem-app", jti="test"),
                           os.environ["JWT_SECRET_KEY"], algorithm="HS256")
        self.assertEqual(self.client.get("/auth/me", headers={"Authorization": "Bearer " + token}).status_code, 401)
        self.lookup_user.return_value = None
        self.assertEqual(self.client.get("/auth/me", headers=self.headers).status_code, 401)
        self.lookup_manager.return_value = None
        self.assertEqual(self.client.get("/auth/me", headers=self.admin_headers).status_code, 401)

    def test_admin_routes_and_private_user_reads(self):
        for method, path in (("get", "/user"), ("get", "/manager"), ("post", "/manager"), ("get", "/post_item")):
            self.assertEqual(getattr(self.client, method)(path, headers=self.headers).status_code, 403)
        with patch("routers.user.user_service.get_user", return_value=[]):
            self.assertEqual(self.client.get("/user", headers=self.admin_headers).status_code, 200)
        self.assertEqual(self.client.get("/user/other", headers=self.headers).status_code, 403)
        self.assertEqual(self.client.get("/user/buyer", headers=self.headers).status_code, 200)
        self.lookup_manager.assert_called_once_with(self.db, "manager")

    def test_mutations_reject_other_user_ids_before_service(self):
        cases = [
            ("post", "/purchase_item", {"user_user_id": "other", "sell_product_sell_product_code": "product"}, "routers.purchase_item.purchase_item_service.create_purchase_item"),
            ("post", "/wishlist", {"user_user_id": "other", "sell_product_sell_product_code": "product"}, "routers.wishlist.wishlist_service.set_wishlist"),
            ("post", "/recharge", {"user_user_id": "other", "recharge_account": "account", "recharge_price": 100}, "routers.recharge.recharge_service.create_recharge"),
            ("delete", "/user/other", {}, "routers.user.user_service.delete_user_id"),
            ("put", "/user/other", {"user_phone": "010", "user_email": "test@example.com", "user_address": "address"}, "routers.user.user_service.put_user_id"),
            ("delete", "/wishlist/other/product", None, "routers.wishlist.wishlist_service.set_wishlist"),
        ]
        for method, path, body, service in cases:
            with self.subTest(path=path), patch(service) as mutation:
                response = self.client.request(method, path, json=body, headers=self.headers)
                self.assertEqual(response.status_code, 403, response.text)
                mutation.assert_not_called()

    def test_purchase_and_recharge_resolve_user_from_token(self):
        purchase = PurchaseItemResponse(purchase_item_code="code", user_user_id="buyer", purchase_item_date="date", sell_product_sell_product_code="product")
        with patch("routers.purchase_item.purchase_item_service.create_purchase_item", return_value=purchase) as service:
            response = self.client.post("/purchase_item", json={"sell_product_sell_product_code": "product"}, headers=self.headers)
            self.assertEqual(response.status_code, 201)
            self.assertEqual(service.call_args.args[1].user_user_id, "buyer")
        from schemas.recharge import RechargeCreateResponse
        recharge = RechargeCreateResponse(message="done", recharge_seq=1, user_user_id="buyer", recharge_date="date", recharge_account="account", recharge_price=100, user_money=100)
        with patch("routers.recharge.recharge_service.create_recharge", return_value=recharge) as service:
            response = self.client.post("/recharge", json={"recharge_account": "account", "recharge_price": 100}, headers=self.headers)
            self.assertEqual(response.status_code, 201)
            self.assertEqual(service.call_args.args[1].user_user_id, "buyer")
        wished = WishlistResponse(wishlist_seq=1, user_user_id="buyer", sell_product_sell_product_code="product", wishlist_date="date", wishlist_update="date", wishlist_status="관심")
        with patch("routers.wishlist.wishlist_service.set_wishlist", return_value=wished) as service:
            response = self.client.post("/wishlist", json={"sell_product_sell_product_code": "product"}, headers=self.headers)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(service.call_args.args[1], "buyer")

    def test_private_records_and_lists(self):
        purchase = PurchaseItemResponse(purchase_item_code="code", user_user_id="other", purchase_item_date="date", sell_product_sell_product_code="product")
        recharge = RechargeResponse(recharge_seq=1, user_user_id="other", recharge_date="date", recharge_account="account", recharge_price=100)
        for path, service, result in (("/purchase_item/code", "routers.purchase_item.purchase_item_service.get_purchase_item_code", purchase),
                                       ("/recharge/1", "routers.recharge.recharge_service.get_recharge_seq", recharge)):
            with self.subTest(path=path), patch(service, return_value=result):
                self.assertEqual(self.client.get(path, headers=self.headers).status_code, 403)
                self.assertEqual(self.client.get(path, headers=self.admin_headers).status_code, 200)
        for path in ("/purchase_item?user_id=other", "/recharge?user_id=other", "/wishlist/other"):
            self.assertEqual(self.client.get(path, headers=self.headers).status_code, 403)
        with patch("routers.purchase_item.purchase_item_service.get_purchase_item", return_value=[]) as service:
            self.assertEqual(self.client.get("/purchase_item", headers=self.headers).status_code, 200)
            self.assertEqual(service.call_args.args[1], "buyer")
        self.assertEqual(self.client.get("/purchase_item", headers=self.admin_headers).status_code, 422)

    def test_product_owner_is_required_for_update_and_delete(self):
        cursor = self.db.cursor.return_value.__enter__.return_value
        cursor.fetchone.return_value = {"sell_product_code": "product"}
        cursor.fetchall.return_value = [{"user_user_id": "other"}]
        with patch("routers.sell_product.sell_product_service.delete_sell_product_code") as service:
            self.assertEqual(self.client.delete("/sell_product/product", headers=self.headers).status_code, 403)
            service.assert_not_called()
        payload = dict(sell_product_title="title", sell_product_image="image", sell_product_contents="contents", sell_product_sell_price=100)
        with patch("routers.sell_product.sell_product_service.put_sell_product_code") as service:
            self.assertEqual(self.client.put("/sell_product/product", json=payload, headers=self.headers).status_code, 403)
            service.assert_not_called()
        cursor.fetchall.return_value = [{"user_user_id": "buyer"}]
        with patch("routers.sell_product.sell_product_service.put_sell_product_code", return_value=None) as service:
            self.assertEqual(self.client.put("/sell_product/product", json=payload, headers=self.headers).status_code, 404)
            service.assert_called_once()
        for call in cursor.execute.call_args_list:
            self.assertIn("FOR UPDATE", call.args[0])

    def test_all_protected_operations_require_token(self):
        schema = app.openapi()
        count = 0
        for path, operations in schema["paths"].items():
            for method, operation in operations.items():
                if not operation.get("security"):
                    continue
                concrete = path.replace("{user_id}", "buyer").replace("{manager_id}", "manager").replace("{sell_product_code}", "product").replace("{post_item_code}", "post").replace("{purchase_item_code}", "purchase").replace("{recharge_seq}", "1").replace("{exchange_seq}", "1").replace("{cybermoney_pay_code}", "payment").replace("{cancel_code}", "cancel").replace("{room_id}", "room")
                with self.subTest(method=method, path=concrete):
                    response = self.client.request(method, concrete)
                    self.assertEqual(response.status_code, 401, response.text)
                count += 1
        self.assertEqual(count, 41)
        self.lookup_user.assert_not_called()

    def test_product_reads_stay_public_and_manager_cannot_buy(self):
        with patch("routers.sell_product.sell_product_service.get_sell_product", return_value=[]):
            self.assertEqual(self.client.get("/sell_product").status_code, 200)
        self.assertEqual(self.client.post("/purchase_item", json={"sell_product_sell_product_code": "product"}, headers=self.admin_headers).status_code, 403)


if __name__ == "__main__":
    unittest.main()
