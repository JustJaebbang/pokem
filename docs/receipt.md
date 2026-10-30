# 접수 등록과 조회

`POST /receipt`는 로그인한 매니저만 등록할 수 있습니다.
사용자 ID는 연결한 `pay`에서 가져오며 매니저는 로그인 계정으로 기록합니다.
`receipt_amount`는 접수 수량으로 해석합니다.

```json
{
  "pay_pay_no": "결제번호",
  "receipt_amount": 1,
  "sell_product_sell_product_code": "상품코드"
}
```

접수번호는 `pay_no + 한국 접수일자(YYYYMMDD)`로 생성합니다.
접수일시는 `YYYY-MM-DD HH:MM:SS`로 저장합니다.
같은 결제로 당일 중복 등록하면 409, 합친 번호가 DB의 64자 제한을 초과하면 422입니다.

`GET /receipt?limit=20&offset=0`, `GET /receipt/{receipt_no}`에서
사용자는 본인 결제에 연결된 내역만, 매니저와 director는 전체를 조회합니다.
director는 등록할 수 없습니다.

기존 DB 컬럼만 사용하며 접수 기록을 등록해도 결제 상태·금액·사용자 잔액은 변경하지 않습니다.
결제와 상품 사이의 직접 연결은 현재 DB에 없으므로 상품 코드는 요청으로 지정합니다.
