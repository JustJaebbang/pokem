from fastapi import HTTPException

from security import hash_password, verify_password

from schemas.auth import LoginRequest

from schemas.manager import ManagerCreate, ManagerResponse, ManagerLoginResponse, ManagerUpdate


MANAGER_COLUMNS = """manager_id, manager_name, manager_phone, manager_email,
    manager_dept, manager_active, manager_updated_at"""


# 관리자 테이블에서 검증한 경우에만 manager 역할을 반환합니다.
def login_manager(db, login: LoginRequest) -> ManagerLoginResponse:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT manager_id, manager_password, manager_name,
                   manager_phone, manager_email, manager_dept,
                   manager_active, manager_updated_at
            FROM manager
            WHERE manager_id = %s
            """,
            (login.login_id,),
        )
        manager = cursor.fetchone()
    if (
        manager is None
        or not manager.get("manager_active", True)
        or not verify_password(login.password, manager["manager_password"])
    ):
        raise HTTPException(status_code=401, detail="아이디 또는 비밀번호가 올바르지 않습니다.")
    return ManagerLoginResponse(account=ManagerResponse(**manager))


# 관리자 정보를 저장하고 등록 결과를 반환합니다.
def create_manager(db, manager: ManagerCreate) -> ManagerResponse:
    try:
        password_hash = hash_password(manager.manager_password)
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
                    password_hash,
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
            SELECT {columns}
            FROM manager
            ORDER BY manager_active DESC, manager_id
            """.format(columns=MANAGER_COLUMNS)
        )
        rows = cursor.fetchall()
    # DB에서 받은 딕셔너리를 응답 스키마로 변환합니다.
    return [ManagerResponse(**row) for row in rows]


# ID로 관리자를 조회하고, 존재하지 않으면 None을 반환합니다.
def get_manager_id(db, manager_id: str) -> ManagerResponse | None:
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT {columns}
            FROM manager
            WHERE manager_id = %s
            """.format(columns=MANAGER_COLUMNS),
            (manager_id,),  # 매개변수가 하나인 튜플에도 쉼표가 필요합니다.
        )
        row = cursor.fetchone()
    return ManagerResponse(**row) if row else None


def update_manager(db, manager_id: str, request: ManagerUpdate) -> ManagerResponse:
    """Director가 매니저 정보와 활성 상태를 변경하고 진행 업무를 안전하게 재배정한다."""
    from datetime import datetime
    from zoneinfo import ZoneInfo

    changes = request.model_dump(
        exclude_unset=True,
        exclude={"reassign_to_manager_id"},
    )
    replacement = request.reassign_to_manager_id
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute(
                "SELECT manager_id, manager_active FROM manager WHERE manager_id = %s FOR UPDATE",
                (manager_id,),
            )
            current = cursor.fetchone()
            if current is None:
                raise HTTPException(status_code=404, detail="매니저를 찾을 수 없습니다.")

            if request.manager_active is False:
                if replacement == manager_id:
                    raise HTTPException(status_code=422, detail="같은 매니저에게 재배정할 수 없습니다.")
                # 완료된 이력은 원래 담당자를 유지하고 진행 중인 업무만 넘긴다.
                active_queries = (
                    (
                        "inspection_request",
                        "(SELECT COUNT(*) FROM inspect i "
                        "WHERE i.inspect_requested_no = inspection_request.inspection_request_no "
                        "AND i.inspect_status = '검수완료') "
                        "< COALESCE(inspection_request.inspection_request_amount, 0)",
                    ),
                    ("inspect", "inspect_status <> '검수완료'"),
                    ("`return`", "return_status <> '반환완료'"),
                    ("delivery", "delivery_status <> '배송완료'"),
                )
                counts = []
                for table, condition in active_queries:
                    cursor.execute(
                        f"SELECT COUNT(*) AS value FROM {table} WHERE manager_manager_id = %s AND {condition}",
                        (manager_id,),
                    )
                    counts.append(int(cursor.fetchone()["value"]))
                if sum(counts) > 0 and not replacement:
                    raise HTTPException(
                        status_code=409,
                        detail="진행 중 업무가 있어 재배정할 활성 매니저가 필요합니다.",
                    )
                if replacement:
                    cursor.execute(
                        "SELECT manager_id FROM manager WHERE manager_id = %s AND manager_active = 1 FOR UPDATE",
                        (replacement,),
                    )
                    if cursor.fetchone() is None:
                        raise HTTPException(status_code=404, detail="재배정할 활성 매니저를 찾을 수 없습니다.")
                    for table, condition in active_queries:
                        cursor.execute(
                            f"UPDATE {table} SET manager_manager_id = %s WHERE manager_manager_id = %s AND {condition}",
                            (replacement, manager_id),
                        )

            changes["manager_updated_at"] = datetime.now(
                ZoneInfo("Asia/Seoul")
            ).strftime("%Y-%m-%d %H:%M:%S")
            allowed = {
                "manager_name",
                "manager_phone",
                "manager_email",
                "manager_dept",
                "manager_active",
                "manager_updated_at",
            }
            columns = [name for name in changes if name in allowed]
            assignments = ", ".join(f"{name} = %s" for name in columns)
            cursor.execute(
                f"UPDATE manager SET {assignments} WHERE manager_id = %s",
                tuple(changes[name] for name in columns) + (manager_id,),
            )
        result = get_manager_id(db, manager_id)
        if result is None:
            raise RuntimeError("변경한 매니저를 조회할 수 없습니다.")
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise
