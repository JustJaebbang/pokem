from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class ProposalCreate(BaseModel):
    # 작성자, 번호, 작성일, 초기 상태는 서버에서 정한다.
    model_config = ConfigDict(extra="forbid")

    proposal_name: str = Field(min_length=1, max_length=100, pattern=r"\S")
    proposal_contents: str = Field(min_length=1, max_length=500, pattern=r"\S")
    case_case_code: str = Field(min_length=1, max_length=45, pattern=r"\S")


class ProposalReview(BaseModel):
    # 대기 상태로 되돌리거나 작성 내용을 함께 변경할 수 없다.
    model_config = ConfigDict(extra="forbid")

    proposal_status: Literal["승인", "반려"]


class ProposalResponse(BaseModel):
    proposal_no: str
    proposal_name: str | None = None
    proposal_contents: str | None = None
    proposal_date: str | None = None
    # 기존 DB의 상태값도 읽을 수 있도록 조회 응답은 문자열로 유지한다.
    proposal_status: str | None = None
    case_case_code: str
    manager_manager_id: str | None = None
    director_director_id: str | None = None
