from fastapi import APIRouter, Depends, HTTPException, Path, Query

from database import get_db
from dependencies import get_current_account, get_current_manager, get_current_director
from schemas.proposal import ProposalCreate, ProposalReview, ProposalResponse
from services import proposal_service

router = APIRouter(prefix="/proposal", tags=["proposal"], dependencies=[Depends(get_current_manager)])


@router.post("", response_model=ProposalResponse, status_code=201)
def create_proposal(request: ProposalCreate, db=Depends(get_db), current=Depends(get_current_account)):
    # 작성과 결재 역할을 분리한다. 작성자는 요청값으로 지정할 수 없다.
    if current.role != "manager":
        raise HTTPException(status_code=403, detail="제안은 매니저가 작성해야 합니다.")
    return proposal_service.create_proposal(db, request, current.account.manager_id)


@router.get("", response_model=list[ProposalResponse])
def get_proposals(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db=Depends(get_db), current=Depends(get_current_account),
):
    manager_id = current.account.manager_id if current.role == "manager" else None
    return proposal_service.get_proposals(db, limit, offset, manager_id=manager_id)


@router.get("/{proposal_no}", response_model=ProposalResponse)
def get_proposal(
    proposal_no: str = Path(min_length=1, max_length=64),
    db=Depends(get_db), current=Depends(get_current_account),
):
    manager_id = current.account.manager_id if current.role == "manager" else None
    proposal = proposal_service.get_proposal(db, proposal_no, manager_id=manager_id)
    if proposal is None:
        raise HTTPException(status_code=404, detail="제안을 찾을 수 없습니다.")
    return proposal


@router.patch("/{proposal_no}/review", response_model=ProposalResponse)
def review_proposal(
    request: ProposalReview, proposal_no: str = Path(min_length=1, max_length=64),
    db=Depends(get_db), director=Depends(get_current_director),
):
    return proposal_service.review_proposal(db, proposal_no, request, director.director_id)
