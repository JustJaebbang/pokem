# pokem
card 검수 및 대리판매, 사용자간 중고거래 플랫폼

## 허재영
### 26.10.27~28
- user CRUD - D user의 판매상품이나 참조하는 부분에 대한 CASCADE 설정 결정해야함
- sell_product CRU - 로그인 기능 구현하면 C user_id 부분 수정해야함
- post_item CR
- wishlist CRD
- purchase_item CR
- recharge CR
- login
FastAPI 구현 및 검증 완료

- user가 sell_product 판매 등록(post_item)시 DB에 sell_product 생성 -> post_item 생성 후 commit 트랜잭션 구현 및 검증 완료

- user가 sell_product 구매시 구매 기록과 거래중 상태를 함께 저장. 거래완료일은 구매확정 시 기록
구매 시 상품 행 잠금으로 같은 상품의 동시 구매를 막음

- login - 실제 user_id, user_passward 검증 후 jwt 토큰 발급하여 Authorization 구현 및 검증 완료
토큰별(role) 인증된 API만 사용 가능하게 구현

### 26.10.27~28
- cybermoney_pay CR
FastAPI 구현 및 검증 완료

- purchase_item 생성 시 cybermoney_pay가 하나의 트랜잭션으로 작동하게 구현 및 검증 완료

## 남궁인성
```
manager CR
FastAPI 구현

login 시도 시 auth를 통하여 user, manager에 대해서 테이블 데이터를 확인 후 일치하는 사용자의 role(역할)을 반환하도록 구현
```
