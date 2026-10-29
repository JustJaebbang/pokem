"""실행: 프로젝트 루트에서 python tests/verify_delivery_db.py

기존 구매/매니저 데이터를 사용하며, 배송업체와 배송 INSERT는 모두 롤백한다.
실제 순번 테이블을 사용하며 순번 증가도 롤백한다. 마이그레이션을 먼저 적용해야 한다.
"""
import sys
from pathlib import Path
from uuid import uuid4

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi import HTTPException
from pymysql.err import IntegrityError

from database import get_connection
from schemas.delivery import DeliveryCreate
from services import delivery_service


class RollbackOnlyConnection:
    """서비스의 커밋을 보류하고 오류 시 해당 호출의 작업만 되돌린다."""

    def __init__(self, connection):
        self.connection = connection

    def cursor(self):
        return self.connection.cursor()

    def begin(self):
        with self.cursor() as cursor:
            cursor.execute("SAVEPOINT delivery_check")

    def commit(self):
        pass

    def rollback(self):
        with self.cursor() as cursor:
            cursor.execute("ROLLBACK TO SAVEPOINT delivery_check")


def expect_http(status, action):
    try:
        action()
    except HTTPException as exc:
        assert exc.status_code == status, (exc.status_code, status)
    else:
        raise AssertionError(f"Expected HTTP {status}")


def snapshot(connection):
    with connection.cursor() as cursor:
        result = {}
        for table in ("delivery", "delivery_company", "purchase_item", "manager", "delivery_sequence"):
            cursor.execute(f"SELECT COUNT(*) AS n FROM `{table}`")
            result[table] = cursor.fetchone()["n"]
        cursor.execute("SELECT delivery_date, last_seq FROM delivery_sequence ORDER BY delivery_date")
        result["sequence_values"] = cursor.fetchall()
        return result


def main():
    connection = get_connection()
    initial = snapshot(connection)
    fixture_company = "verify_" + uuid4().hex
    created_numbers = []
    try:
        with connection.cursor() as cursor:
            # 롤백 가능한 테이블인지, 트리거 부작용이 없는지 쓰기 전에 확인한다.
            cursor.execute("""SELECT TABLE_NAME, ENGINE FROM information_schema.TABLES
                WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME IN ('delivery','delivery_company','delivery_sequence')""")
            assert all(row["ENGINE"] == "InnoDB" for row in cursor.fetchall())
            cursor.execute("""SELECT COUNT(*) AS n FROM information_schema.TRIGGERS
                WHERE TRIGGER_SCHEMA=DATABASE() AND EVENT_OBJECT_TABLE IN ('delivery','delivery_company','delivery_sequence')""")
            assert cursor.fetchone()["n"] == 0, "Review trigger side effects before running"
            cursor.execute("""SELECT p.purchase_item_code, p.sell_product_sell_product_code,
                       p.user_user_id AS buyer
                FROM purchase_item p
                WHERE NOT EXISTS (SELECT 1 FROM delivery d
                    WHERE d.purchase_item_purchase_item_code=p.purchase_item_code)
                ORDER BY p.purchase_item_code LIMIT 2""")
            purchases = cursor.fetchall()
            assert len(purchases) >= 2, "Need two eligible existing purchases"
            cursor.execute("SELECT manager_id FROM manager LIMIT 1")
            manager = cursor.fetchone()
            assert manager, "Need an existing manager"
        db = RollbackOnlyConnection(connection)
        request = DeliveryCreate(
            purchase_item_code=purchases[0]["purchase_item_code"],
            manager_manager_id=manager["manager_id"],
            delivery_company_delivery_company_code=fixture_company,
        )
        expect_http(404, lambda: delivery_service.create_delivery(db, request))
        print("PASS: nonexistent delivery company rejected (404)")
        with connection.cursor() as cursor:
            cursor.execute("""INSERT INTO delivery_company
                (delivery_company_code, delivery_company_name) VALUES (%s, %s)""",
                (fixture_company, "Rollback-only verification"))
        first = delivery_service.create_delivery(db, request)
        created_numbers.append(first.delivery_no)
        assert first.user_user_id == purchases[0]["buyer"]
        assert first.manager_manager_id == manager["manager_id"]
        assert first.delivery_company_delivery_company_code == fixture_company
        assert first.delivery_status == "배송준비"
        assert len(first.delivery_no) == 14 and first.delivery_no.isdigit()
        assert first.delivery_no[:8] == first.delivery_date[:10].replace("-", "")
        assert first.purchase_item_code == purchases[0]["purchase_item_code"]
        assert first.sell_product_sell_product_code == purchases[0]["sell_product_sell_product_code"]
        print("PASS: existing buyer/product/manager linked; date + six-digit sequence stored")
        expect_http(409, lambda: delivery_service.create_delivery(db, request))
        print("PASS: duplicate purchase rejected (409)")
        second = delivery_service.create_delivery(db, request.model_copy(update={
            "purchase_item_code": purchases[1]["purchase_item_code"]
        }))
        created_numbers.append(second.delivery_no)
        assert second.delivery_no == first.delivery_no[:8] + f"{int(first.delivery_no[-6:]) + 1:06d}"
        assert second.user_user_id == purchases[1]["buyer"]
        print("PASS: second purchase receives next daily sequence")
        assert delivery_service.get_delivery(db, first.delivery_no) == first
        assert delivery_service.get_delivery(db, first.delivery_no, first.user_user_id) == first
        assert delivery_service.get_delivery(db, first.delivery_no, "__not_the_buyer__") is None
        rows = delivery_service.get_deliveries(db, user_id=first.user_user_id)
        assert rows and all(row.user_user_id == first.user_user_id for row in rows)
        print("PASS: stored detail/list schemas and buyer filtering")
        # 서비스를 우회한 INSERT도 DB의 UNIQUE/외래 키 제약으로 거부되어야 한다.
        for purchase_code, expected in ((first.purchase_item_code, 1062), (uuid4().hex, 1452)):
            with connection.cursor() as cursor:
                cursor.execute("SAVEPOINT constraint_check")
                try:
                    cursor.execute("""INSERT INTO delivery (
                        delivery_no, delivery_date, delivery_status, manager_manager_id,
                        delivery_company_delivery_company_code, purchase_item_purchase_item_code
                    ) VALUES (%s, %s, %s, %s, %s, %s)""", (
                        "verify_" + uuid4().hex, first.delivery_date, first.delivery_status,
                        first.manager_manager_id, fixture_company, purchase_code,
                    ))
                except IntegrityError as exc:
                    assert exc.args[0] == expected, exc.args[0]
                else:
                    raise AssertionError(f"Expected DB constraint error {expected}")
                finally:
                    cursor.execute("ROLLBACK TO SAVEPOINT constraint_check")
        print("PASS: database UNIQUE and purchase foreign key constraints")
        with connection.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) AS n FROM delivery WHERE delivery_no IN (%s,%s)", tuple(created_numbers))
            assert cursor.fetchone()["n"] == 2
    finally:
        connection.rollback()
        connection.close()
        # 새 연결로 확인하여 테스트 트랜잭션 밖에 변경이 남지 않았음을 검사한다.
        check = get_connection()
        try:
            assert snapshot(check) == initial, "Row counts changed; inspect concurrent writes"
            with check.cursor() as cursor:
                cursor.execute("SELECT COUNT(*) AS n FROM delivery_company WHERE delivery_company_code=%s", (fixture_company,))
                assert cursor.fetchone()["n"] == 0
                for number in created_numbers:
                    cursor.execute("SELECT COUNT(*) AS n FROM delivery WHERE delivery_no=%s", (number,))
                    assert cursor.fetchone()["n"] == 0
            print("PASS: separate connection confirms fixture and deliveries rolled back")
        finally:
            check.rollback()
            check.close()


if __name__ == "__main__":
    main()
