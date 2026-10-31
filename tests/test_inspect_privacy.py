import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from fastapi import FastAPI
from fastapi.testclient import TestClient
from database import get_db
from dependencies import get_current_account, get_current_user
from routers.inspect import router
from schemas.inspect import InspectResponse

class InspectPrivacyTests(unittest.TestCase):
    def setUp(self):
        self.app = FastAPI()
        self.app.include_router(router)
        self.app.dependency_overrides[get_db] = lambda: MagicMock()
        self.app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(user_id='owner')
        self.item = InspectResponse(inspect_code='INS-1', inspect_serial_code='SV1', seq=1,
            inspect_requested_no='20261030000001', inspect_status='검수완료', inspect_date=None,
            inspect_grade='A', inspect_grade_reason='internal reason', inspect_user_choice='의사확인대기',
            inspect_user_choice_at=None, manager_manager_id='manager', user_user_id='owner')
    def test_user_list_detail_and_choice_do_not_return_internal_reason(self):
        self.app.dependency_overrides[get_current_account] = lambda: SimpleNamespace(role='user')
        with TestClient(self.app) as client:
            with patch('routers.inspect.inspect_service.get_inspects', return_value=[self.item]):
                response = client.get('/inspect')
                self.assertEqual(response.status_code, 200)
                self.assertNotIn('inspect_grade_reason', response.json()[0])
                self.assertEqual(response.json()[0]['inspect_grade'], 'A')
            with patch('routers.inspect.inspect_service.get_inspects', return_value=self.item):
                response = client.get('/inspect/INS-1')
                self.assertEqual(response.status_code, 200)
                self.assertNotIn('inspect_grade_reason', response.json())
            with patch('routers.inspect.inspect_service.choose_inspect', return_value=self.item):
                response = client.put('/inspect/INS-1/choice', json={'inspect_user_choice': '반환'})
                self.assertEqual(response.status_code, 200)
                self.assertNotIn('inspect_grade_reason', response.json())
    def test_manager_can_still_read_reason(self):
        self.app.dependency_overrides[get_current_account] = lambda: SimpleNamespace(role='manager')
        with TestClient(self.app) as client:
            with patch('routers.inspect.inspect_service.get_inspects', return_value=[self.item]):
                response = client.get('/inspect')
                self.assertEqual(response.json()[0]['inspect_grade_reason'], 'internal reason')
            with patch('routers.inspect.inspect_service.get_inspects', return_value=self.item):
                response = client.get('/inspect/INS-1')
                self.assertEqual(response.json()['inspect_grade_reason'], 'internal reason')
