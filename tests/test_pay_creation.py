import unittest
from datetime import datetime
from unittest.mock import MagicMock, patch
from zoneinfo import ZoneInfo

from fastapi import HTTPException
from pydantic import ValidationError

from schemas.inspection_request import InspectionRequestManagerUpdate
from schemas.pay import PayCreate
from services import inspection_request_service, pay_service


class PayCreationTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.request = PayCreate(inspection_request_inspection_request_no="20261028000001")

    def test_creation_uses_inspection_ids_and_same_date_for_number(self):
        self.cursor.fetchone.side_effect = [
            {"user_user_id": "user01", "manager_manager_id": "manager01", "inspection_request_amount": 2}, None
        ]
        with patch("services.pay_service.datetime") as clock:
            clock.now.return_value = datetime(2026, 10, 28, 20, 30, 45, tzinfo=ZoneInfo("Asia/Seoul"))
            result = pay_service.create_pay(self.db, self.request)
        self.assertEqual(result.pay_no, "2026102800000120261028")
        self.assertEqual(result.pay_date, "2026-10-28 20:30:45")
        self.assertEqual(result.pay_status, "결제대기")
        self.assertEqual(result.user_user_id, "user01")
        self.assertEqual(result.manager_manager_id, "manager01")
        self.assertEqual(result.pay_price, 20000)
        self.assertIn("INSERT INTO pay", self.cursor.execute.call_args.args[0])
        self.assertEqual(self.cursor.execute.call_args.args[1][2], 20000)
        self.db.commit.assert_not_called()

    def test_unconfirmed_request_cannot_create_pay(self):
        self.cursor.fetchone.return_value = {"user_user_id": "u", "manager_manager_id": None}
        with self.assertRaises(HTTPException) as error:
            pay_service.create_pay(self.db, self.request)
        self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(self.cursor.execute.call_count, 1)

    def test_existing_pay_cannot_be_created_twice(self):
        self.cursor.fetchone.side_effect = [
            {"user_user_id": "u", "manager_manager_id": "m", "inspection_request_amount": 2}, {"pay_no": "existing"}
        ]
        with self.assertRaises(HTTPException) as error:
            pay_service.create_pay(self.db, self.request)
        self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(self.cursor.execute.call_count, 2)

    def test_pay_failure_rolls_back_manager_assignment(self):
        self.cursor.fetchone.side_effect = [{"manager_manager_id": None}, {"manager_id": "m"}]
        self.cursor.rowcount = 1
        with patch("services.inspection_request_service.pay_service.create_pay", side_effect=RuntimeError("failure")):
            with self.assertRaises(RuntimeError):
                inspection_request_service.assign_inspection_request_manager(
                    self.db, "20261028000001", InspectionRequestManagerUpdate(manager_manager_id="m")
                )
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_manager_approves_without_price_and_cannot_override_it(self):
        from schemas.inspection_request import InspectionRequestManagerRequest, InspectionRequestCreate
        self.assertIsNone(InspectionRequestManagerRequest().manager_manager_id)
        with self.assertRaises(ValidationError):
            InspectionRequestCreate(user_user_id="u", inspection_request_amount=214749)
        request = InspectionRequestManagerUpdate(manager_manager_id="m")
        self.assertEqual(request.manager_manager_id, "m")
        with self.assertRaises(ValidationError):
            InspectionRequestManagerUpdate(manager_manager_id="m", pay_price=1)

    def test_fee_calculation_bounds_and_invalid_legacy_counts(self):
        from inspection_pricing import calculate_inspection_fee
        self.assertEqual(calculate_inspection_fee(1), 10000)
        self.assertEqual(calculate_inspection_fee(3), 30000)
        self.assertEqual(calculate_inspection_fee(214748), 2147480000)
        for amount in (None, 0, -1, True, 214749):
            with self.subTest(amount=amount):
                self.cursor.fetchone.side_effect = [
                    {"user_user_id":"u", "manager_manager_id":"m", "inspection_request_amount":amount}, None]
                with self.assertRaises(HTTPException) as error:
                    pay_service.create_pay(self.db, self.request)
                self.assertEqual(error.exception.status_code, 409)


if __name__ == "__main__":
    unittest.main()
