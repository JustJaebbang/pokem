# 판매자 후기 조회

`GET /review?seller_user_id=seller01`은 판매자 seller01의 일반판매·대리판매 상품에 남겨진 후기를 최근 순으로 반환합니다.
공개 조회이며 기존 ReviewResponse 형식을 유지합니다.
후기 테이블의 user_user_id는 작성자이므로 판매자 조건에 사용하지 않습니다.
일반판매는 post_item.user_user_id, 대리판매는 inspection_request.user_user_id가 판매자입니다.
EXISTS로 관계를 조회하므로 중복된 등록 관계가 있어도 후기 행을 복제하지 않습니다.

기존 `GET /review?sell_product_code=상품번호`와 `GET /review`를 유지합니다.
`GET /review?seller_user_id=seller01&sell_product_code=상품번호`는 두 조건을 모두 만족하는 후기만 반환합니다.
알 수 없는 판매자나 후기가 없는 판매자는 빈 배열을 반환합니다. 빈 ID·20자 초과 ID는 422입니다.
현재 전체 목록이 반환되므로 앱이 전체 건수·평균을 계산합니다. API 응답에 별도 통계 컬럼을 추가하지 않았습니다.
DB 테이블·컬럼 추가나 데이터 갱신은 필요하지 않습니다.
