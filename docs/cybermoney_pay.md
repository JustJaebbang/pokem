# 사이버머니 결제를 포함한 상품 구매

구매 버튼은 `POST /purchase_item` 한 번만 호출합니다.
별도 `POST /cybermoney_pay`는 제거했으며 결제 내역 조회 API는 유지합니다.

1. `POST /auth/login`으로 로그인하고 Swagger Authorize에 access token을 입력합니다.
2. `POST /recharge`로 잔액을 충전합니다. 현재 충전은 실제 입금·결제 승인과 연결되지 않은 테스트 처리입니다.
3. `POST /purchase_item`에 상품 코드를 전달합니다.

```json
{
  "sell_product_sell_product_code": "구매할 판매상품코드"
}
```

구매자는 로그인 계정으로 확정하며 금액은 잠근 상품 행의 DB 가격을 사용합니다.
같은 사용자 ID를 기존처럼 보내는 것은 허용하지만 다른 사용자 ID를 보내면 403입니다.
요청·응답은 기존 구매 API 형식을 유지하며, 성공하면 201과 구매 정보를 반환합니다.

구매 서비스가 트랜잭션을 시작하고 아래 작업을 수행합니다.

1. 사용자 잔액과 상품 행을 잠그고 본인 상품 여부·상품 상태·중복 구매를 확인합니다.
2. 결제 금액과 잔액을 확인한 뒤 사이버머니를 차감합니다.
3. `purchase_item`을 저장합니다.
4. 같은 연결로 `cybermoney_pay`를 저장합니다.
5. 상품을 `거래중`으로 바꿉니다.
6. 모두 성공한 경우에만 한 번 commit합니다. 실패하면 잔액과 모든 기록·상태 변경을 rollback합니다.

결제 기록은 구매 코드를 외래 키로 참조하므로 DB INSERT 순서는 구매 → 결제입니다.
결제 가능 확인과 잔액 차감은 구매 INSERT보다 먼저 실행합니다.
결제 서비스의 `deduct_cybermoney`, `insert_cybermoney_pay`는 내부에서 begin·commit·rollback하지 않습니다.

잔액 부족·잘못된 상품 가격·판매 중이 아닌 상품·중복 구매는 409이며 구매 및 결제 기록을 남기지 않습니다.
이전 분리 API로 생성된 미결제 구매 기록은 자동 결제하거나 변경하지 않습니다.

| API | 사용법 |
| --- | --- |
| `GET /purchase_item` | 본인의 구매 목록 |
| `GET /purchase_item/{purchase_item_code}` | 본인 또는 관리자의 구매 상세 조회 |
| `GET /cybermoney_pay` | 본인의 결제 목록 |
| `GET /cybermoney_pay/{cybermoney_pay_code}` | 본인 또는 관리자의 결제 상세 조회 |
| `GET /cybermoney_pay?user_id=사용자아이디` | 관리자가 해당 사용자 결제 목록 조회 |
| `GET /auth/me` | 본인의 현재 잔액 확인 |

구매 코드는 `상품코드_구매일시`, 결제 코드는 `구매코드_결제일시` 형식이며
한국 시간과 `%Y%m%d%H%M%S%f` 형식으로 생성합니다.
현재 DB의 결제 코드와 참조 컬럼은 VARCHAR(66)으로 확장되어 있습니다.
새 DB에는 `sql/cybermoney_pay_code_length.sql`의 확장이 필요합니다.
구매 코드 컬럼은 여전히 VARCHAR(45)이므로 상품코드와 구매일시를 합친 길이가 45자 이내여야 합니다.

결제는 구매확정이 아닙니다. `post_item_complete_date`는 변경하지 않습니다.
`cybermoney_give` 저장·판매자 잔액 증가·구매확정·결제 취소 및 환불은 별도 단계입니다.
