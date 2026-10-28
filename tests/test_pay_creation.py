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
        self.request = PayCreate(inspection_request_inspection_request_no="20261028000001", pay_price=15000)

    def test_creation_uses_inspection_ids_and_same_date_for_number(self):
        self.cursor.fetchone.side_effect = [
            {"user_user_id": "user01", "manager_manager_id": "manager01"}, None
        ]
        with patch("services.pay_service.datetime") as clock:
            clock.now.return_value = datetime(2026, 10, 28, 20, 30, 45, tzinfo=ZoneInfo("Asia/Seoul"))
            result = pay_service.create_pay(self.db, self.request)
        self.assertEqual(result.pay_no, "2026102800000120261028203045")
        self.assertEqual(result.pay_date, "2026-10-28 20:30:45")
        self.assertEqual(result.pay_status, "결제대기")
        self.assertEqual(result.user_user_id, "user01")
        self.assertEqual(result.manager_manager_id, "manager01")
        self.assertEqual(result.pay_price, 15000)
        self.assertIn("INSERT INTO pay", self.cursor.execute.call_args.args[0])
        self.assertEqual(self.cursor.execute.call_args.args[1][2], 15000)
        self.db.commit.assert_not_called()

    def test_unconfirmed_request_cannot_create_pay(self):
        self.cursor.fetchone.return_value = {"user_user_id": "u", "manager_manager_id": None}
        with self.assertRaises(HTTPException) as error:
            pay_service.create_pay(self.db, self.request)
        self.assertEqual(error.exception.status_code, 409)
        self.assertEqual(self.cursor.execute.call_count, 1)

    def test_existing_pay_cannot_be_created_twice(self):
        self.cursor.fetchone.side_effect = [
            {"user_user_id": "u", "manager_manager_id": "m"}, {"pay_no": "existing"}
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
                    self.db, "20261028000001", InspectionRequestManagerUpdate(manager_manager_id="m", pay_price=15000)
                )
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_manager_price_is_required_and_must_fit_integer_column(self):
        with self.assertRaises(ValidationError):
            InspectionRequestManagerUpdate(manager_manager_id="m")
        for price in (-1, 2147483648, 10.5, True):
            with self.subTest(price=price):
                with self.assertRaises(ValidationError):
                    InspectionRequestManagerUpdate(manager_manager_id="m", pay_price=price)


if __name__ == "__main__":
    unittest.main()
