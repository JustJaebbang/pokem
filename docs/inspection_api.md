# 검수신청·검수·대리판매 API

실제 DB에 테스트 데이터를 생성하지 않았습니다. 아래 순서로 Swagger에서 검증할 수 있습니다.
검수비는 사용자 결제하기 버튼으로 완료 처리합니다. 실제 외부 결제·배송사 연동은 수행하지 않습니다.

## 1. 일반 사용자: 검수신청

`POST /inspection_request`

```json
{"inspection_request_amount": 2}
```

amount는 비용이 아닌 카드 개수입니다. 검수비는 보증금을 포함해 수량 × 10,000원으로 고정됩니다. 검수완료·비FAKE 카드의 보증금은 카드당 5,000원이며 [보증금 환급](deposit_refund.md) API에서 자동 계산합니다. 신청번호는 날짜와 일별 순번으로 발급합니다.
신청자는 토큰에서 가져옵니다. `GET /inspection_request` 또는 `GET /inspection_request/{request_no}`로 본인 신청을 확인합니다.
관리자는 전체 신청을 조회할 수 있습니다.

### 담당자 승인과 검수비 생성

`PATCH /inspection_request/{신청번호}/manager`에 `{}`를 보내면 로그인한 담당자로 승인합니다.
`manager_manager_id`는 기존 본인 ID 입력도 허용하지만 `pay_price`는 받지 않습니다.
승인과 동시에 저장된 수량으로 검수비를 계산하여 결제대기 건을 생성하고 함께 커밋합니다.
계산 실패·결제 저장 실패 시 승인을 포함해 롤백합니다.
`PATCH /pay/{pay_no}`는 상태만 수정하며 금액 수정은 허용하지 않습니다.
DB INT 한도에 맞춰 신청 수량은 1~214,748장입니다. 기존 결제 내역을 일괄 재계산하지 않습니다.

## 2. 관리자: 실물별 검수 상품 등록

`POST /inspect`

```json
{
  "inspect_requested_no": "신청번호",
  "inspect_serial_code": "카탈로그 일련코드"
}
```

신청된 상품 개수만큼 호출하며 같은 신청에 서로 다른 카탈로그 상품도 등록할 수 있습니다.
서버가 `INS_일련코드-seq`를 발급합니다. 카탈로그의 검수 순번 증가와 검수 저장은 한 트랜잭션입니다.
신청 행을 잠근 뒤 개수를 확인하므로 초과 등록은 409입니다. 실제 상품이 도착하고 식별된 후 관리자가 등록하는 흐름입니다.
검수와 판매 순번은 독립적입니다.

`GET /inspect?request_no=신청번호`로 해당 신청의 검수 목록을 확인합니다.
`GET /inspect/{inspect_code}`는 상세 조회입니다. 사용자는 본인 상품만, 관리자는 전체를 조회할 수 있습니다.

## 3. 관리자: 검수 시작·완료

`POST /inspect/{inspect_code}/start`: 검수대기 → 검수중. 본문 없음.

`POST /inspect/{inspect_code}/complete`

```json
{"inspect_grade": "A", "inspect_grade_reason": "모서리와 표면 상태 양호"}
```

검수중일 때만 완료할 수 있습니다. 완료일과 담당 관리자, 등급/사유를 저장하고 사용자 선택을 의사확인대기로 둡니다.
등급은 판매상품 컬럼과 호환되도록 1~20자, 사유는 1~200자입니다.
검수 완료 뒤 결과 수정은 이번 구현에 포함하지 않았습니다.

## 4. 신청 사용자: 반환 또는 대리판매 선택

`PUT /inspect/{inspect_code}/choice`

```json
{"inspect_user_choice": "대리판매"}
```

`반환` 또는 `대리판매`만 허용합니다. 완료 전 선택·타인 선택은 차단합니다.
같은 선택을 반복하면 현재 값을 반환하며, 이미 확정한 선택을 다른 값으로 변경하는 것은 허용하지 않습니다.
반환을 선택해도 실제 반송 처리는 별도 절차입니다.

## 5. 관리자: 대리판매 등록

`POST /post_consign_item`

```json
{
  "inspect_inspect_code": "INS_일련코드-1",
  "sell_product_title": "검수 완료 상품",
  "sell_product_image": "https://example.com/card.jpg",
  "sell_product_contents": "검수 등급 A",
  "sell_product_sell_price": 10000
}
```

검수완료·대리판매 선택·미등록 조건을 확인합니다.
판매 순번 증가 → sell_product 생성 → post_consign_item 저장을 한 트랜잭션으로 처리합니다.
일반판매 post_item은 생성하지 않습니다. 등급은 입력값 대신 검수 결과를 사용하고 상태는 판매중으로 고정합니다.
응답에 생성된 판매상품 정보와 대리판매등록 코드를 포함합니다.
등록 코드는 기존 VARCHAR(45)에 맞춰 CON_와 UUID를 조합합니다.
현재 구매 코드 길이 제한 때문에 생성 상품 코드가 24자를 넘으면 409로 거부하고 순번도 원복합니다.

`GET /post_consign_item`과 `GET /post_consign_item/{code}`로 본인 소유 등록 또는 관리자의 전체 등록을 조회합니다.

## 기존 거래 연결

상품 목록과 상세는 기존 `/sell_product`로 조회합니다.
실제 판매자는 관리자 대신 `검수신청.user_user_id`입니다.
기존 구매·구매확정·취소·리뷰·채팅이 일반/대리판매의 소유자를 공통 조회합니다.
대리판매 구매확정은 소유자의 잔액을 증가시키고 post_consign_item_complete_date를 기록합니다.
일반판매 post_item_complete_date를 변경하지 않습니다.

일반 상품의 수정·삭제·재판매는 판매자만 허용합니다.
대리판매 상품의 수정·재판매는 관리자만 허용하고 직접 삭제는 409로 막습니다.
대리판매도 기존 당사자 취소 승인 흐름을 사용합니다. 실제 플랫폼 배송·반품 단계에 따른 추가 취소 정책은 아직 포함하지 않았습니다.

검증은 별도 SQLite 테스트 DB에서 수행했습니다. 실제 MySQL 행 잠금 경합을 직접 부하 검증한 것은 아닙니다.


## 파일 및 Swagger 그룹

- 검수신청: routers/inspection_request.py, services/inspection_request_service.py, schemas/inspection_request.py
- 검수: routers/inspect.py, services/inspect_service.py, schemas/inspect.py
- 대리판매등록: routers/post_consign_item.py, services/post_consign_item_service.py, schemas/post_consign_item.py
- 공유 조회·검증 함수: services/inspection_common.py

Swagger 그룹도 inspection_request / inspect / post_consign_item으로 구분합니다.
분리 전 API 경로·요청/응답·권한·트랜잭션 동작은 유지합니다.
