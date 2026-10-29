# 제안 작성과 결재

`POST /proposal`은 로그인한 매니저만 작성할 수 있습니다.
작성 매니저는 토큰에서 결정하며 초기 상태는 `대기`입니다.
번호는 한국 날짜 `YYYYMMDD`와 6자리 일별 순번으로 생성합니다.

```json
{
  "proposal_name": "케이스 발주 제안",
  "proposal_contents": "케이스 구매가 필요합니다.",
  "case_case_code": "ppp_ccc-1"
}
```

`GET /proposal?limit=20&offset=0`과 `GET /proposal/{proposal_no}`에서
매니저는 본인이 작성한 제안만, director는 전체 제안을 조회할 수 있습니다.
일반 사용자는 접근할 수 없습니다.

`PATCH /proposal/{proposal_no}/review`는 director만 처리할 수 있습니다.

```json
{
  "proposal_status": "반려"
}
```

상태는 `승인` 또는 `반려`만 받으며 처리 director를 자동 기록합니다.
대기 상태에서만 처리할 수 있고, 이미 처리한 제안을 다시 처리하면 409입니다.
승인 시 주문 생성이나 재고 변경은 수행하지 않습니다.

DB에 `sql/proposal_workflow.sql`을 한 번 적용해야 합니다.
기존 제안의 상태와 director 정보는 유지하고 작성 매니저는 NULL로 둡니다.
작성 매니저가 없는 기존 제안은 director만 조회할 수 있으며,
기존 상태가 `대기`가 아니라면 승인·반려 대상으로 처리하지 않습니다.
