from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.inspection_request import (
    InspectionRequestCreate,
    InspectionRequestManagerUpdate,
    InspectionRequestResponse,
)


def create_inspection_request(
    db, request: InspectionRequestCreate
) -> InspectionRequestResponse:
    # 번호의 날짜 부분과 저장 일시가 같은 한국 시간을 사용하도록 한 번만 계산한다.
    now = datetime.now(ZoneInfo("Asia/Seoul"))
    request_date = now.strftime("%Y-%m-%d %H:%M:%S")
    try:
        # 순번 증가와 요청 저장을 함께 확정한다. 실패하면 순번 증가도 취소된다.
        db.begin()
        with db.cursor() as cursor:
            # 1. 해당 날짜의 첫 요청은 1로 생성하고, 이후 요청은 순번을 1 증가시킨다.
            # INSERT/UPDATE가 카운터 행을 잠그므로 같은 날짜의 동시 요청은 대기한다.
            cursor.execute(
                """
                INSERT INTO inspection_request_sequence (request_date, last_seq)
                VALUES (%s, 1)
                ON DUPLICATE KEY UPDATE last_seq = last_seq + 1
                """,
                (now.date(),),
            )
            # 2. 이번 트랜잭션에서 발급한 순번을 읽고 commit/rollback까지 잠금을 유지한다.
            cursor.execute(
                """
                SELECT last_seq FROM inspection_request_sequence
                WHERE request_date = %s FOR UPDATE
                """,
                (now.date(),),
            )
            seq = cursor.fetchone()["last_seq"]
            # 6자리 범위를 넘으면 번호 형식이 깨지므로 요청을 거절한다.
            if seq > 999999:
                raise HTTPException(status_code=409, detail="일일 검수 요청 번호가 소진되었습니다.")
            # 예: 2026-10-28의 첫 요청 → 20261028000001 (YYYYMMDD + 6자리 SEQ).
            request_no = int(f"{now:%Y%m%d}{seq:06d}")
            # 3. 자동 증가 번호 대신 직접 조합한 번호로 검수 요청을 저장한다.
            cursor.execute(
                """
                INSERT INTO inspection_request (
                    inspection_request_no,
                    inspection_request_date,
                    inspection_request_amount,
                    user_user_id,
                    manager_manager_id
                )
                VALUES (%s, %s, %s, %s, NULL)
                """,
                (
                    request_no,
                    request_date,
                    request.inspection_request_amount,
                    request.user_user_id,
                ),
            )

        # 4. 저장 결과를 응답 스키마로 검증한 뒤 순번과 요청을 함께 확정한다.
        result = get_inspection_request(db, request_no)
        if result is None:
            raise RuntimeError("생성한 검수 요청을 조회할 수 없습니다.")
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        # MySQL 1452: 참조할 사용자 또는 매니저가 없어 외래키 제약을 위반한 경우.
        if exc.args[0] == 1452:
            raise HTTPException(
                status_code=400, detail="사용자 또는 담당 매니저가 존재하지 않습니다."
            ) from exc
        raise
    except Exception:
        # 조회나 응답 검증 중 오류가 발생한 경우에도 전체 변경을 취소한다.
        db.rollback()
        raise


def get_inspection_requests(db) -> list[InspectionRequestResponse]:
    # 날짜와 순번이 큰 요청부터 조회한다. 결과가 없으면 빈 목록을 반환한다.
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT inspection_request_no, inspection_request_date,
                   inspection_request_amount, user_user_id, manager_manager_id
            FROM inspection_request
            ORDER BY inspection_request_no DESC
            """
        )
        rows = cursor.fetchall()
    return [InspectionRequestResponse(**row) for row in rows]


def get_inspection_request(db, inspection_request_no: int) -> InspectionRequestResponse | None:
    # 요청 번호로 한 건을 조회한다. 없으면 router에서 404로 처리하도록 None을 반환한다.
    with db.cursor() as cursor:
        cursor.execute(
            """
            SELECT inspection_request_no, inspection_request_date,
                   inspection_request_amount, user_user_id, manager_manager_id
            FROM inspection_request
            WHERE inspection_request_no = %s
            """,
            (inspection_request_no,),
        )
        row = cursor.fetchone()
    return InspectionRequestResponse(**row) if row else None


def assign_inspection_request_manager(
    db, inspection_request_no: int, request: InspectionRequestManagerUpdate
) -> InspectionRequestResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            # 요청 행을 잠가 동시 배정 시 기존 담당자가 덮어써지는 것을 막는다.
            cursor.execute(
                """
                SELECT manager_manager_id FROM inspection_request
                WHERE inspection_request_no = %s FOR UPDATE
                """,
                (inspection_request_no,),
            )
            row = cursor.fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="해당 검수 요청을 찾을 수 없습니다.")
            if row["manager_manager_id"] is not None:
                raise HTTPException(status_code=409, detail="이미 담당 매니저가 배정된 요청입니다.")

            # 외래키 설정 여부와 관계없이 존재하는 매니저만 배정한다.
            cursor.execute(
                "SELECT manager_id FROM manager WHERE manager_id = %s FOR UPDATE",
                (request.manager_manager_id,),
            )
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="해당 매니저를 찾을 수 없습니다.")
            cursor.execute(
                """
                UPDATE inspection_request SET manager_manager_id = %s
                WHERE inspection_request_no = %s AND manager_manager_id IS NULL
                """,
                (request.manager_manager_id, inspection_request_no),
            )
            if cursor.rowcount != 1:
                raise HTTPException(status_code=409, detail="담당 매니저를 배정할 수 없습니다.")

        result = get_inspection_request(db, inspection_request_no)
        if result is None:
            raise RuntimeError("변경한 검수 요청을 조회할 수 없습니다.")
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1452:
            raise HTTPException(status_code=400, detail="담당 매니저가 존재하지 않습니다.") from exc
        raise
    except Exception:
        db.rollback()
        raise
