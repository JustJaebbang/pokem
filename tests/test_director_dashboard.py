import unittest
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from database import get_db
from dependencies import get_current_director
from routers.director import router
from schemas.case import CaseResponse
from schemas.director import DirectorDashboardResponse, DirectorMetrics
from schemas.manager import ManagerResponse
from schemas.proposal import ProposalResponse


class DirectorDashboardTests(unittest.TestCase):
    def setUp(self):
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_db] = lambda: object()
        app.dependency_overrides[get_current_director] = lambda: SimpleNamespace(
            director_id="director1"
        )
        self.client = TestClient(app)
        self.addCleanup(self.client.close)

    def test_dashboard_static_path_returns_director_summary(self):
        # /dashboard가 /{director_id}로 처리되지 않고 집계 응답을 반환하는지 검증한다.
        dashboard = DirectorDashboardResponse(
            metrics=DirectorMetrics(
                users=7,
                managers=2,
                unassigned_requests=1,
                inspections_in_progress=2,
                completed_inspections=5,
                active_consignments=3,
                pending_proposals=1,
                orders=3,
                deliveries_in_progress=2,
                returns_in_progress=1,
                payments=4,
                refunds=2,
                case_stock=10,
            ),
            proposals=[
                ProposalResponse(
                    proposal_no="20261101000001",
                    proposal_name="재고 발주",
                    proposal_status="대기",
                    case_case_code="CASE1",
                    manager_manager_id="manager1",
                )
            ],
            managers=[
                ManagerResponse(
                    manager_id="manager1",
                    manager_name="담당자",
                    manager_phone="010-0000-0000",
                    manager_email="manager@example.com",
                    manager_dept="검수팀",
                )
            ],
            cases=[CaseResponse(case_code="CASE1", case_stock=10)],
        )
        with patch(
            "routers.director.director_service.get_director_dashboard",
            return_value=dashboard,
        ) as load:
            response = self.client.get("/director/dashboard")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["metrics"]["pending_proposals"], 1)
        self.assertEqual(response.json()["managers"][0]["manager_id"], "manager1")
        load.assert_called_once()


if __name__ == "__main__":
    unittest.main()
