from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from pymysql.err import IntegrityError

from schemas.proposal import ProposalCreate, ProposalReview, ProposalResponse


PROPOSAL_COLUMNS = """proposal_no, proposal_name, proposal_contents, proposal_date,
    proposal_status, case_case_code, manager_manager_id, director_director_id"""


def create_proposal(db, request: ProposalCreate, manager_id: str) -> ProposalResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            cursor.execute("SELECT manager_id FROM manager WHERE manager_id = %s FOR UPDATE", (manager_id,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="작성 매니저를 찾을 수 없습니다.")
            cursor.execute("SELECT case_code FROM `case` WHERE case_code = %s FOR UPDATE", (request.case_case_code,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="케이스를 찾을 수 없습니다.")

            # 번호는 한국 날짜 YYYYMMDD + 6자리 일별 순번이다.
            now = datetime.now(timezone(timedelta(hours=9)))
            cursor.execute(
                """INSERT INTO proposal_sequence (proposal_date, last_seq) VALUES (%s, 1)
                ON DUPLICATE KEY UPDATE last_seq = last_seq + 1""", (now.date(),),
            )
            cursor.execute("SELECT last_seq FROM proposal_sequence WHERE proposal_date = %s FOR UPDATE", (now.date(),))
            seq = cursor.fetchone()["last_seq"]
            if seq > 999999:
                raise HTTPException(status_code=409, detail="일일 제안 등록 한도를 초과했습니다.")
            result = ProposalResponse(
                **request.model_dump(), proposal_no=f"{now:%Y%m%d}{seq:06d}",
                proposal_date=now.strftime("%Y-%m-%d %H:%M:%S"),
                proposal_status="대기", manager_manager_id=manager_id,
            )
            # 처리 director는 작성 시 정하지 않고 실제 승인·반려한 계정으로 기록한다.
            cursor.execute(
                """INSERT INTO proposal (proposal_no, proposal_name, proposal_contents,
                    proposal_date, proposal_status, case_case_code, manager_manager_id)
                VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (result.proposal_no, result.proposal_name, result.proposal_contents,
                 result.proposal_date, result.proposal_status, result.case_case_code, manager_id),
            )
        db.commit()
        return result
    except IntegrityError as exc:
        db.rollback()
        if exc.args[0] == 1062:
            raise HTTPException(status_code=409, detail="이미 등록된 제안 번호입니다.") from exc
        if exc.args[0] == 1452:
            raise HTTPException(status_code=400, detail="연결된 매니저 또는 케이스를 확인해주세요.") from exc
        raise
    except Exception:
        db.rollback()
        raise


def get_proposals(db, limit: int = 20, offset: int = 0, manager_id: str | None = None) -> list[ProposalResponse]:
    # 매니저는 본인 작성 건만, director는 전체 제안을 조회한다.
    owner_filter = "WHERE manager_manager_id = %s" if manager_id is not None else ""
    params = (manager_id, limit, offset) if manager_id is not None else (limit, offset)
    with db.cursor() as cursor:
        cursor.execute(
            f"""SELECT {PROPOSAL_COLUMNS} FROM proposal {owner_filter}
            ORDER BY proposal_date DESC, proposal_no DESC LIMIT %s OFFSET %s""", params,
        )
        rows = cursor.fetchall()
    return [ProposalResponse(**row) for row in rows]


def get_proposal(db, proposal_no: str, manager_id: str | None = None) -> ProposalResponse | None:
    owner_filter = " AND manager_manager_id = %s" if manager_id is not None else ""
    params = (proposal_no, manager_id) if manager_id is not None else (proposal_no,)
    with db.cursor() as cursor:
        cursor.execute(f"SELECT {PROPOSAL_COLUMNS} FROM proposal WHERE proposal_no = %s{owner_filter}", params)
        row = cursor.fetchone()
    return ProposalResponse(**row) if row else None


def review_proposal(db, proposal_no: str, request: ProposalReview, director_id: str) -> ProposalResponse:
    try:
        db.begin()
        with db.cursor() as cursor:
            # 상태 확인부터 변경까지 잠가 동시 승인·반려와 중복 처리를 막는다.
            cursor.execute(f"SELECT {PROPOSAL_COLUMNS} FROM proposal WHERE proposal_no = %s FOR UPDATE", (proposal_no,))
            row = cursor.fetchone()
            if row is None:
                raise HTTPException(status_code=404, detail="제안을 찾을 수 없습니다.")
            if row["proposal_status"] != "대기":
                raise HTTPException(status_code=409, detail="대기 상태의 제안만 처리할 수 있습니다.")
            cursor.execute("SELECT director_id FROM director WHERE director_id = %s FOR UPDATE", (director_id,))
            if cursor.fetchone() is None:
                raise HTTPException(status_code=404, detail="처리 director를 찾을 수 없습니다.")
            cursor.execute(
                """UPDATE proposal SET proposal_status = %s, director_director_id = %s
                WHERE proposal_no = %s""",
                (request.proposal_status, director_id, proposal_no),
            )
            result = ProposalResponse(**{
                **row, "proposal_status": request.proposal_status, "director_director_id": director_id,
            })
        db.commit()
        return result
    except Exception:
        db.rollback()
        raise
