import os
import unittest
from unittest.mock import MagicMock, patch

from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

from database import get_db
from routers.auth import router as auth_router
from routers.director import router as director_router
from routers.manager import router as manager_router
from routers.delivery import router as delivery_router
from schemas.director import DirectorResponse
from schemas.manager import ManagerResponse
from schemas.delivery import DeliveryResponse
from security import create_access_token, decode_access_token, hash_password


class DirectorAuthTests(unittest.TestCase):
    def setUp(self):
        settings = patch.dict(os.environ, {"JWT_SECRET_KEY": "director-auth-test-key-" * 3})
        settings.start()
        self.addCleanup(settings.stop)
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.director = DirectorResponse(director_id="director1", director_rank="director")
        self.record = {**self.director.model_dump(), "director_password": hash_password("password1")}
        app = FastAPI()
        for router in (auth_router, director_router, manager_router, delivery_router):
            app.include_router(router)
        app.dependency_overrides[get_db] = lambda: self.db
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def headers(self, role="director", subject="director1"):
        token, _ = create_access_token(subject, role)
        return {"Authorization": "Bearer " + token}

    def test_common_login_returns_director_token_and_me(self):
        self.cursor.fetchone.side_effect = [None, None, self.record]
        response = self.client.post("/auth/login", json={"login_id": "director1", "password": "password1"})
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertEqual(body["role"], "director")
        claims = decode_access_token(body["access_token"])
        self.assertEqual((claims["role"], claims["sub"]), ("director", "director1"))
        self.assertNotIn("director_password", body["account"])
        self.assertEqual(response.headers["Cache-Control"], "no-store")
        with patch("dependencies.director_service.get_director_id", return_value=self.director):
            me = self.client.get("/auth/me", headers={"Authorization": "Bearer " + body["access_token"]})
        self.assertEqual(me.status_code, 200)
        self.assertEqual(me.json()["role"], "director")

    def test_invalid_director_password_never_issues_token(self):
        for stored in (None, self.record, {**self.record, "director_password": "wrong"}):
            self.cursor.fetchone.side_effect = [None, None, stored]
            with patch("services.auth_service.create_access_token") as issue:
                response = self.client.post("/auth/login", json={"login_id": "director1", "password": "wrong"})
            self.assertEqual(response.status_code, 401)
            issue.assert_not_called()

    def test_director_has_manager_and_director_access(self):
        with patch("dependencies.director_service.get_director_id", return_value=self.director), \
             patch("routers.manager.manager_service.get_manager", return_value=[]), \
             patch("routers.director.director_service.get_directors", return_value=[]):
            for path in ("/manager", "/director"):
                self.assertEqual(self.client.get(path, headers=self.headers()).status_code, 200)

    def test_manager_cannot_access_director_management(self):
        manager = ManagerResponse(manager_id="m", manager_name="m", manager_phone="010", manager_email="m@example.com", manager_dept="test")
        with patch("dependencies.manager_service.get_manager_id", return_value=manager):
            headers = self.headers("manager", "m")
            for path in ("/director", "/director/director1"):
                self.assertEqual(self.client.get(path, headers=headers).status_code, 403)
            self.assertEqual(self.client.post("/director", headers=headers, json={"director_id": "new", "director_password": "password"}).status_code, 403)

    def test_director_must_assign_real_manager_for_delivery(self):
        request = {"purchase_item_code": "purchase1", "delivery_company_delivery_company_code": "company1"}
        delivery = DeliveryResponse(
            **request, delivery_no="20261029000001", user_user_id="buyer",
            manager_manager_id="m", sell_product_sell_product_code="product1",
        )
        with patch("dependencies.director_service.get_director_id", return_value=self.director), \
             patch("routers.delivery.delivery_service.create_delivery", return_value=delivery) as create:
            self.assertEqual(self.client.post("/delivery", headers=self.headers(), json=request).status_code, 422)
            create.assert_not_called()
            response = self.client.post("/delivery", headers=self.headers(), json={**request, "manager_manager_id": "m"})
            self.assertEqual(response.status_code, 201)
            self.assertEqual(create.call_args.args[1].manager_manager_id, "m")

    def test_deleted_director_is_unauthorized(self):
        with patch("dependencies.director_service.get_director_id", return_value=None):
            self.assertEqual(self.client.get("/auth/me", headers=self.headers()).status_code, 401)

    def test_director_manager_ambiguous_login_is_rejected(self):
        from schemas.manager import ManagerLoginResponse
        from schemas.director import DirectorLoginResponse
        manager = ManagerResponse(manager_id="director1", manager_name="m", manager_phone="010", manager_email="m@example.com", manager_dept="test")
        with patch("services.auth_service.user_service.login_user", side_effect=HTTPException(status_code=401)), \
             patch("services.auth_service.manager_service.login_manager", return_value=ManagerLoginResponse(account=manager)), \
             patch("services.auth_service.director_service.login_director", return_value=DirectorLoginResponse(account=self.director)), \
             patch("services.auth_service.create_access_token") as issue:
            response = self.client.post("/auth/login", json={"login_id": "director1", "password": "password1"})
        self.assertEqual(response.status_code, 409)
        issue.assert_not_called()


if __name__ == "__main__":
    unittest.main()
