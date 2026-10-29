# 폐기 이력 등록과 조회

`POST /discard`는 매니저만 등록할 수 있으며 등록자는 로그인 계정으로 기록합니다.

```json
{
  "sell_product_sell_product_code": "상품코드"
}
```

`discard_date`는 한국 시간 기준 `YYYY-MM-DD HH:MM:SS`로 자동 생성합니다.
DB의 기본키는 `manager_manager_id`와 `sell_product_sell_product_code`의 조합입니다.
같은 조합으로 중복 등록하면 409를 반환합니다.

`GET /discard?limit=20&offset=0`에서 매니저와 director는 등록 매니저와 관계없이 전체 기록을 조회합니다.
단건 조회는 복합 기본키를 사용한 `GET /discard/{manager_id}/{sell_product_code}`입니다.
일반 사용자는 접근할 수 없고 director는 조회만 가능합니다.

기존 DB 컬럼으로 폐기 이력만 저장하며 상품 삭제나 판매 상태 변경은 수행하지 않습니다.
DB 기본키 구조상 다른 매니저가 같은 상품을 기록하는 것은 허용됩니다.
