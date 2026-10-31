# 검수 물품 반환

`return`은 반환할 검수 물품, 소유자, 담당 매니저만 관리합니다.
배송 일자와 상태는 `delivery`에서 관리하며, 반환 날짜·상태·완료일시는 중복 저장하지 않습니다.

사용자가 검수완료 물품에 `반환`을 선택하면 반환 건을 자동 생성합니다.
판매상품 등록 없이 `inspect_inspect_code`로 연결하며 검수 물품당 한 건만 허용합니다.
선택과 반환 접수는 같은 트랜잭션에서 확정됩니다. 같은 선택 재요청은 중복 생성하지 않습니다.
번호는 `RET_` + UUID의 32자리 hex입니다.

## 속성

| 컬럼 | 의미 |
| --- | --- |
| return_no | 반환 건 번호 |
| inspect_inspect_code | 반환할 검수 물품, UNIQUE·외래키 |
| user_user_id | 검수 신청에서 확인한 소유자 |
| manager_manager_id | 담당 매니저, 배정 전 NULL |

반환 선택 시점은 `inspect.inspect_user_choice_at`으로 조회하며, 목록도 이 시점의 내림차순입니다.
같은 시점이면 return_no 내림차순으로 정렬합니다.

## API

모든 요청에 Bearer 토큰이 필요합니다.

| API | 권한 | 동작 |
| --- | --- | --- |
| `GET /return?limit=20&offset=0` | 사용자·매니저 | 사용자는 본인 내역만, 매니저는 전체 조회 |
| `GET /return/{return_no}` | 사용자·매니저 | 본인 내역 또는 매니저 조회, 타인·없는 건은 404 |
| `PATCH /return/{return_no}/manager` | 매니저 | 로그인한 매니저를 배정 |

응답에는 return_no, inspect_inspect_code, user_user_id, manager_manager_id만 포함합니다.
담당자 배정 본문은 `{}`입니다. manager_manager_id를 명시하면 로그인 매니저와 같아야 합니다.
이미 배정된 건은 409를 반환하며 재배정하지 않습니다. 배정 시 날짜·상태를 변경하지 않습니다.
반환 생성용 POST는 제공하지 않습니다. 기존 `PUT /inspect/{inspect_code}/choice`를 사용합니다.
반환 완료 API도 제공하지 않습니다. 배송 진행·완료는 delivery 담당 기능에서 처리합니다.

## 배송 연결

배송 코드와 테이블은 이번 구현에서 변경하지 않습니다.
기존 `delivery.return_return_no`는 반환 건의 `return_no`를 참조하도록 유지합니다.
주소·택배사·운송장·배송 일자·배송 상태는 delivery 담당 기능에서 관리합니다.
담당자가 배정되었다는 사실은 발송이나 배송 완료를 의미하지 않습니다.
반환 목록의 배송 정보가 필요한 앱은 배송 담당 API의 반환 건 조회 기능과 연결해야 합니다.

## DB 변경

기존 의사 코드·판매상품 연결 구조의 빈 return 테이블에는 `docs/return_workflow.sql`을 한 번 적용합니다.
앞서 날짜·상태가 있는 반환 기능을 적용한 DB에는 `docs/return_delivery_fields.sql`만 적용합니다.
두 SQL을 순서대로 실행하는 방식이 아닙니다. 현재 DB 구조에 맞는 파일 하나를 사용합니다.
삭제되는 날짜·상태 값은 보존되지 않습니다. return_no와 물품·사용자·매니저 연결 및 delivery 참조는 유지합니다.
SQL은 MySQL DDL이므로 암묵적으로 커밋됩니다.

GET /return?inspect_code=검수번호로 본인의 특정 검수 물품 반환 건을 조회할 수 있습니다. 기존 사용자 권한 필터와 limit/offset은 유지됩니다. 사용자 앱은 나 → 반환내역과 검수 결과의 반환내역 보기에서 조회하며 배송 API는 변경하지 않습니다.
