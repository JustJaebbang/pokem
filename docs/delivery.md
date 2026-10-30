# 구매·반송 배송 등록

`POST /delivery`에서 구매번호 또는 반송번호 중 정확히 하나를 지정합니다.
매니저 ID를 생략하면 로그인한 매니저로 등록합니다.

구매 배송:

```json
{
  "purchase_item_code": "구매번호",
  "delivery_company_delivery_company_code": "배송업체코드"
}
```

반송 배송:

```json
{
  "return_no": "반송번호",
  "delivery_company_delivery_company_code": "배송업체코드"
}
```

둘 다 입력하거나 둘 다 생략하면 422, 원본이 없으면 404,
같은 구매·반송 건에 이미 배송이 있으면 409를 반환합니다.
구매 배송은 `purchase_item`에서 사용자와 `sell_product_sell_product_code`를 가져옵니다.
반송 배송은 `return`에서 사용자와 `inspect_inspect_code`를 가져옵니다.
반송번호의 생성 규칙은 `inspect_code + return_date(YYYYMMDD)`입니다.
배송번호는 한국 날짜 `YYYYMMDD` + 일별 6자리 순번이며 두 유형이 같은 순번을 사용합니다.

`GET /delivery`와 `GET /delivery/{delivery_no}`에서 두 유형을 함께 조회합니다.
일반 사용자는 선택된 원본의 사용자 ID가 본인인 배송만 조회할 수 있습니다.
구매 응답은 `return_no`와 `inspect_inspect_code`가 NULL이고,
반송 응답은 `purchase_item_code`와 `sell_product_sell_product_code`가 NULL입니다.

기존 구매 기반 DB에는 `sql/delivery_return.sql`을 먼저 적용합니다.
구매·반송 기록 생성과 배송 등록은 별도 API 호출입니다.

`return`은 검수를 참조하며 별도의 상품 FK를 사용하지 않습니다.
이전에 추가한 반송 상품 FK를 제거할 때는 `sql/return_inspect_delivery.sql`을 사용합니다.
기존 반송번호는 변경하지 않으며 상품 코드와 검수 코드를 서로 변환하거나 추정하지 않습니다.
