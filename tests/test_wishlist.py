import unittest
from unittest.mock import MagicMock

from fastapi import HTTPException

from services.wishlist_service import get_wishlist, set_wishlist


class WishlistTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.cursor = self.db.cursor.return_value.__enter__.return_value
        self.cursor.lastrowid = 7
        self.row = {
            "wishlist_seq": 7, "wishlist_date": "2026-10-28T10:00:00+09:00",
            "wishlist_update": "2026-10-28T10:00:00+09:00", "wishlist_status": "관심",
            "user_user_id": "test-user", "sell_product_sell_product_code": "test-product",
        }

    def prepare(self, row):
        self.cursor.fetchone.side_effect = [{"user_id": "test-user"}, {"sell_product_code": "test-product"}, row]

    def test_create(self):
        self.prepare(None)
        result = set_wishlist(self.db, "test-user", "test-product", True)
        self.assertEqual(result.wishlist_seq, 7)
        self.assertEqual(result.wishlist_status, "관심")
        self.assertIn("INSERT INTO wishlist", self.cursor.execute.call_args.args[0])
        self.assertEqual(self.cursor.execute.call_args.args[1][-2:], ("test-user", "test-product"))
        self.db.begin.assert_called_once()
        self.db.commit.assert_called_once()
        self.db.rollback.assert_not_called()

    def test_repeated_add_does_not_insert_or_update(self):
        self.prepare(self.row)
        result = set_wishlist(self.db, "test-user", "test-product", True)
        self.assertEqual(self.cursor.execute.call_count, 3)
        self.assertEqual(result.wishlist_update, self.row["wishlist_update"])

    def test_remove_and_reactivate_reuse_row(self):
        for active, old_status, new_status in ((False, "관심", "해제"), (True, "해제", "관심")):
            with self.subTest(active=active):
                self.setUp()
                self.prepare({**self.row, "wishlist_status": old_status})
                result = set_wishlist(self.db, "test-user", "test-product", active)
                self.assertEqual(result.wishlist_status, new_status)
                self.assertEqual(result.wishlist_seq, 7)
                self.assertIn("UPDATE wishlist", self.cursor.execute.call_args.args[0])
                self.assertEqual(result.wishlist_date, self.row["wishlist_date"])

    def test_repeated_remove_does_not_write(self):
        self.prepare({**self.row, "wishlist_status": "해제"})
        set_wishlist(self.db, "test-user", "test-product", False)
        self.assertEqual(self.cursor.execute.call_count, 3)

    def test_missing_user_product_or_wishlist_rolls_back(self):
        cases = ([None], [{"user_id": "test-user"}, None], [{"user_id": "test-user"}, {"sell_product_code": "test-product"}, None])
        for rows in cases:
            with self.subTest(rows=rows):
                self.setUp()
                self.cursor.fetchone.side_effect = rows
                with self.assertRaises(HTTPException) as error:
                    set_wishlist(self.db, "test-user", "test-product", False)
                self.assertEqual(error.exception.status_code, 404)
                self.db.rollback.assert_called_once()
                self.db.commit.assert_not_called()

    def test_insert_failure_rolls_back(self):
        self.prepare(None)
        self.cursor.execute.side_effect = [None, None, None, RuntimeError("write failed")]
        with self.assertRaises(RuntimeError):
            set_wishlist(self.db, "test-user", "test-product", True)
        self.db.rollback.assert_called_once()
        self.db.commit.assert_not_called()

    def test_list_filters_active_and_returns_models(self):
        self.cursor.fetchone.return_value = {"user_id": "test-user"}
        self.cursor.fetchall.return_value = [self.row]
        result = get_wishlist(self.db, "test-user")
        self.assertEqual(result[0].wishlist_seq, 7)
        self.assertEqual(self.cursor.execute.call_args.args[1], ("test-user", "관심"))
        self.cursor.fetchall.return_value = []
        self.assertEqual(get_wishlist(self.db, "test-user"), [])

    def test_list_missing_user(self):
        self.cursor.fetchone.return_value = None
        with self.assertRaises(HTTPException) as error:
            get_wishlist(self.db, "missing")
        self.assertEqual(error.exception.status_code, 404)


if __name__ == "__main__":
    unittest.main()
