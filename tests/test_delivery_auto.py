import sqlite3
import unittest
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from schemas.purchase_item import PurchaseItemCreate
from services import delivery_service, purchase_item_service


def install_delivery_schema(connection):
    connection.executescript("""
        CREATE TABLE delivery_company(delivery_company_code TEXT PRIMARY KEY);
        INSERT INTO delivery_company VALUES ('CO');
        CREATE TABLE purchase_item(purchase_item_code TEXT PRIMARY KEY, user_user_id TEXT,
            sell_product_sell_product_code TEXT, purchase_item_status TEXT DEFAULT '거래중');
        CREATE TABLE delivery_sequence(delivery_date TEXT PRIMARY KEY, last_seq INTEGER);
        CREATE TABLE delivery(delivery_no TEXT PRIMARY KEY, delivery_date TEXT, delivery_status TEXT,
            manager_manager_id TEXT REFERENCES manager(manager_id),
            delivery_company_delivery_company_code TEXT REFERENCES delivery_company(delivery_company_code),
            purchase_item_purchase_item_code TEXT UNIQUE REFERENCES purchase_item(purchase_item_code),
            return_return_no TEXT UNIQUE REFERENCES `return`(return_no));
        CREATE TABLE delivery_status_history(history_id INTEGER PRIMARY KEY AUTOINCREMENT,
            delivery_delivery_no TEXT REFERENCES delivery(delivery_no), previous_status TEXT, changed_status TEXT,
            manager_manager_id TEXT REFERENCES manager(manager_id), changed_at TEXT, memo TEXT);
    """)


class AutomaticPurchaseDeliveryTests(unittest.TestCase):
    def run_purchase(self, kind='consign', fail=False):
        db = MagicMock()
        c = db.cursor.return_value.__enter__.return_value
        c.fetchone.side_effect = [
            {'user_id': 'buyer', 'user_money': 30000},
            {'sell_product_sell_status': '판매중', 'sell_product_sell_price': 10000},
            *([{'post_consign_item_expires_at': None, 'manager_manager_id': 'M'}] if kind == 'consign' else []),
            None,
        ]
        post = {'registration_type': kind, 'user_user_id': 'seller', 'post_item_complete_date': None}
        with patch.object(purchase_item_service, 'get_sale_registrations', return_value=[post]), \
             patch.object(purchase_item_service.cybermoney_pay_service, 'deduct_cybermoney', return_value=20000), \
             patch.object(purchase_item_service.cybermoney_pay_service, 'insert_cybermoney_pay'), \
             patch.object(purchase_item_service, 'ensure_automatic_delivery') as automatic:
            if fail:
                automatic.side_effect = RuntimeError('history insert failed')
                with self.assertRaises(RuntimeError):
                    purchase_item_service.create_purchase_item(db, PurchaseItemCreate(user_user_id='buyer', sell_product_sell_product_code='P'))
                db.rollback.assert_called_once()
                db.commit.assert_not_called()
            else:
                result = purchase_item_service.create_purchase_item(db, PurchaseItemCreate(user_user_id='buyer', sell_product_sell_product_code='P'))
                db.commit.assert_called_once()
                if kind == 'consign':
                    automatic.assert_called_once_with(c, manager_id='M', user_id='buyer', purchase_code=result.purchase_item_code, product_code='P')
                else:
                    automatic.assert_not_called()

    def test_consignment_purchase_registers_delivery_inside_transaction(self):
        self.run_purchase()

    def test_direct_purchase_does_not_auto_register(self):
        self.run_purchase('direct')

    def test_delivery_failure_rolls_back_purchase_and_payment(self):
        self.run_purchase(fail=True)
