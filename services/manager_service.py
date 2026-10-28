from schemas.manager import ManagerCreate, ManagerResponse


# 관리자 정보를 저장하고 등록 결과를 반환합니다.
def create_manager(db, manager: ManagerCreate) -> ManagerResponse:
    try:
        with db.cursor() as cursor:
            # 입력값은 SQL에 직접 삽입하지 않고 별도 매개변수로 전달합니다.
            cursor.execute(
                """
                INSERT INTO manager
                    (manager_id, manager_password, manager_name,
                     manager_phone, manager_email, manager_dept)
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    manager.manager_id,
                    manager.manager_password,
                    manager.manager_name,
                    manager.manager_phone,
                    manager.manager_email,
                    manager.manager_dept,
                ),
            )
        # 저장을 확정하고 ID로 다시 조회해 응답을 구성합니다.
        db.commit()
        return get_manager_id(db, manager.manager_id)
    except Exception:
        # 오류가 발생하면 아직 확정되지 않은 변경을 취소합니다.
        db.rollback()
        raise


# 전체 관리자를 조회합니다. 비밀번호는 조회 및 응답에서 제외합니다.
def get_manager(db) -> list[ManagerResponse]:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT manager_id, manager_name, manager_phone,
                   manager_email, manager_dept
            FROM manager
            """
        )
        rows = cursor.fetchall()
    # DB에서 받은 딕셔너리를 응답 스키마로 변환합니다.
    return [ManagerResponse(**row) for row in rows]


# ID로 관리자를 조회하고, 존재하지 않으면 None을 반환합니다.
def get_manager_id(db, manager_id: str) -> ManagerResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT manager_id, manager_name, manager_phone,
                   manager_email, manager_dept
            FROM manager
            WHERE manager_id = %s
            """,
            (manager_id,),  # 매개변수가 하나인 튜플에도 쉼표가 필요합니다.
        )
        row = cursor.fetchone()
    return ManagerResponse(**row) if row else None
