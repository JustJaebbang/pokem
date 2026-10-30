import unittest
from unittest.mock import MagicMock
from services.pay_service import get_pays

class PayFilterTests(unittest.TestCase):
    def test_owner_and_request_filters_are_both_applied_with_paging(self):
        db = MagicMock()
        cursor = db.cursor.return_value.__enter__.return_value
        cursor.fetchall.return_value = []
        self.assertEqual(get_pays(db, 2, 0, user_id='owner', request_no='20261030000001'), [])
        query, params = cursor.execute.call_args.args
        self.assertIn('user_user_id = %s AND inspection_request_inspection_request_no = %s', query)
        self.assertEqual(params, ('owner', '20261030000001', 2, 0))
    def test_legacy_paging_without_filters_is_unchanged(self):
        db = MagicMock()
        cursor = db.cursor.return_value.__enter__.return_value
        cursor.fetchall.return_value = []
        get_pays(db)
        self.assertEqual(cursor.execute.call_args.args[1], (20, 0))
