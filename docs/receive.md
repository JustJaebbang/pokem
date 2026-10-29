# 입고 등록과 조회

`POST /receive`는 주문 담당 매니저가 등록합니다.
입고 API는 매니저 전용이며 director와 일반 사용자는 접근할 수 없습니다.

```json
{
  "order_order_no": "주문번호",
  "receive_price": 30000,
  "receive_amount": 10
}
```

`receive_price`는 해당 입고의 총금액입니다. 제조업체와 케이스는 주문에서 가져옵니다.
입고번호는 `order_no + 한국 입고일자(YYYYMMDD)`로 자동 생성합니다.
입고일시는 `YYYY-MM-DD HH:MM:SS`로 저장합니다.
합친 번호가 DB의 64자 제한을 초과하면 422를 반환합니다.

같은 주문의 당일 중복 입고, 주문 수량을 초과하는 누적 입고,
DB INT 범위를 넘는 케이스 재고 증가는 409로 거부합니다.
입고 기록과 케이스 재고 증가는 하나의 트랜잭션으로 처리합니다.
기존 입고 수량이 NULL이면 추가 입고 전에 해당 데이터를 확인해야 합니다.

`GET /receive?limit=20&offset=0`, `GET /receive/{receive_no}`에서
매니저는 본인 담당 내역만 조회합니다. 기존 DB 컬럼만 사용합니다.
