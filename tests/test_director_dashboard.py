import unittest
from types import SimpleNamespace
from unittest.mock import patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from database import get_db
from dependencies import get_current_director
from routers.director import router
from schemas.case import CaseResponse
from schemas.director import (
    DirectorDashboardResponse,
    DirectorDelayedDelivery,
    DirectorInspectionPipeline,
    DirectorLowStockCase,
    DirectorManagerInspectionStat,
    DirectorMetrics,
    DirectorOperationsStatistics,
    DirectorOutstandingOrder,
    DirectorQuitTypeStat,
    DirectorReturnWithoutDelivery,
    DirectorWithdrawalResponse,
)
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
                withdrawn_users=1,
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
            withdrawals=[
                DirectorWithdrawalResponse(
                    user_id="retired-user",
                    user_nickname="탈퇴사용자",
                    quit_date="2026-11-01T12:00:00+09:00",
                    quit_type="서비스 불만",
                    quit_reason="응답이 느립니다.",
                )
            ],
            statistics=DirectorOperationsStatistics(
                pipeline=DirectorInspectionPipeline(
                    unassigned_requests=1,
                    waiting=2,
                    in_progress=1,
                    completed=5,
                ),
                manager_inspections=[
                    DirectorManagerInspectionStat(
                        manager_id="manager1",
                        manager_name="담당자",
                        total=8,
                        completed=5,
                        active=3,
                    )
                ],
                low_stock_cases=[
                    DirectorLowStockCase(case_code="CASE1", case_stock=3)
                ],
                outstanding_orders=[
                    DirectorOutstandingOrder(
                        order_no="ORDER1",
                        case_code="CASE1",
                        order_amount=10,
                        received_amount=4,
                        outstanding_amount=6,
                    )
                ],
                delayed_deliveries=2,
                returns_without_delivery=1,
                quit_types=[DirectorQuitTypeStat(quit_type="서비스 불만", count=1)],
                delayed_delivery_items=[
                    DirectorDelayedDelivery(
                        delivery_no="DELIVERY1",
                        delivery_date="2026-10-28 09:00:00",
                        delivery_status="배송준비",
                        manager_id="manager1",
                        company_code="COMPANY1",
                    )
                ],
                return_without_delivery_items=[
                    DirectorReturnWithoutDelivery(
                        return_no="RETURN1",
                        return_status="반환접수",
                        user_id="user1",
                        manager_id="manager1",
                    )
                ],
            ),
        )
        with patch(
            "routers.director.director_service.get_director_dashboard",
            return_value=dashboard,
        ) as load:
            response = self.client.get("/director/dashboard")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["metrics"]["pending_proposals"], 1)
        self.assertEqual(response.json()["managers"][0]["manager_id"], "manager1")
        self.assertEqual(response.json()["withdrawals"][0]["quit_type"], "서비스 불만")
        self.assertEqual(response.json()["statistics"]["outstanding_orders"][0]["outstanding_amount"], 6)
        load.assert_called_once()

    def test_main_app_registers_dashboard_route(self):
        # 라우터 파일만 존재하고 main.py에서 누락되는 회귀를 방지한다.
        from main import app

        # 현재 FastAPI는 include_router를 지연 확장하므로 생성된 OpenAPI로 확인한다.
        paths = app.openapi()["paths"]
        self.assertIn("/director/dashboard", paths)
        self.assertIn("get", paths["/director/dashboard"])


if __name__ == "__main__":
    unittest.main()
