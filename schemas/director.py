from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field
from schemas.case import CaseResponse
from schemas.manager import ManagerResponse
from schemas.proposal import ProposalResponse


class DirectorCreate(BaseModel):
    # 실제 DB 컬럼 길이와 NULL 허용 여부에 맞춘 등록 입력이다.
    model_config = ConfigDict(extra="forbid")

    director_id: str = Field(min_length=1, max_length=45, pattern=r"\S")
    director_password: str = Field(min_length=1, repr=False)
    director_name: str | None = Field(default=None, max_length=45)
    director_phone: str | None = Field(default=None, max_length=20)
    director_email: str | None = Field(default=None, max_length=255)
    director_rank: str | None = Field(default=None, max_length=45)


class DirectorResponse(BaseModel):
    # 비밀번호와 해시값은 API 응답에 포함하지 않는다.
    director_id: str
    director_name: str | None = None
    director_phone: str | None = None
    director_email: str | None = None
    director_rank: str | None = None


class DirectorLoginResponse(BaseModel):
    role: Literal["director"] = "director"
    account: DirectorResponse


class DirectorSettingsResponse(BaseModel):
    low_stock_threshold: int
    delivery_delay_days: int
    inspection_unit_price: int
    updated_at: str
    director_director_id: str | None = None


class DirectorSettingsUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    low_stock_threshold: int = Field(ge=0, le=2147483647, strict=True)
    delivery_delay_days: int = Field(ge=1, le=365, strict=True)
    inspection_unit_price: int = Field(ge=0, le=2147483647, strict=True)


class DirectorStatisticsPage(BaseModel):
    kind: str
    total: int
    limit: int
    offset: int
    items: list[dict[str, Any]]


class DirectorMetrics(BaseModel):
    users: int
    managers: int
    unassigned_requests: int
    inspections_in_progress: int
    completed_inspections: int
    active_consignments: int
    pending_proposals: int
    orders: int
    deliveries_in_progress: int
    returns_in_progress: int
    payments: int
    refunds: int
    case_stock: int
    withdrawn_users: int


class DirectorWithdrawalResponse(BaseModel):
    # 탈퇴 관리에 필요한 최소 정보만 총괄책임자에게 제공한다.
    user_id: str
    user_nickname: str | None = None
    quit_date: str | None = None
    quit_type: str
    quit_reason: str | None = None


class DirectorInspectionPipeline(BaseModel):
    unassigned_requests: int
    waiting: int
    in_progress: int
    completed: int


class DirectorManagerInspectionStat(BaseModel):
    manager_id: str
    manager_name: str | None = None
    total: int
    completed: int
    active: int


class DirectorLowStockCase(BaseModel):
    case_code: str
    case_stock: int
    threshold: int = 10


class DirectorOutstandingOrder(BaseModel):
    order_no: str
    order_date: str | None = None
    case_code: str
    order_amount: int
    received_amount: int
    outstanding_amount: int


class DirectorQuitTypeStat(BaseModel):
    quit_type: str
    count: int


class DirectorDelayedDelivery(BaseModel):
    delivery_no: str
    delivery_date: str | None = None
    delivery_status: str | None = None
    manager_id: str
    company_code: str | None = None


class DirectorReturnWithoutDelivery(BaseModel):
    return_no: str
    return_status: str
    user_id: str
    manager_id: str | None = None


class DirectorOperationsStatistics(BaseModel):
    pipeline: DirectorInspectionPipeline
    manager_inspections: list[DirectorManagerInspectionStat]
    low_stock_cases: list[DirectorLowStockCase]
    outstanding_orders: list[DirectorOutstandingOrder]
    delayed_deliveries: int
    returns_without_delivery: int
    quit_types: list[DirectorQuitTypeStat]
    delayed_delivery_items: list[DirectorDelayedDelivery]
    return_without_delivery_items: list[DirectorReturnWithoutDelivery]


class DirectorDashboardResponse(BaseModel):
    metrics: DirectorMetrics
    proposals: list[ProposalResponse]
    managers: list[ManagerResponse]
    cases: list[CaseResponse]
    withdrawals: list[DirectorWithdrawalResponse]
    statistics: DirectorOperationsStatistics
    settings: DirectorSettingsResponse
