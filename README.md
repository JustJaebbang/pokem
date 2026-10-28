# pokem

card 검수 및 대리판매, 사용자간 중고거래 플랫폼

## 허재영
### 26.10.27~28

```
user CRUD
sell_product CRU
post_item CR
wishlist CRD
purchase_item CR
recharge CR
FastAPI 구현 및 검증 완료

user가 sell_product 판매 등록(post_item)시 DB에 sell_product 생성 -> post_item 생성 후 commit 트랜잭션 구현 및 검증 완료

user가 sell_product 구매시 구매 기록과 거래중 상태를 함께 저장. 거래완료일은 구매확정 시 기록
구매 시 상품 행 잠금으로 같은 상품의 동시 구매를 막음
user가 sell_product 판매 등록(post_item)시 DB에 sell_product 생성, post_item 생성 후 commit 트랜잭션 구현
```


## 남궁인성
```
manager CR
FastAPI 구현

login 시도 시 auth를 통하여 user, manager에 대해서 테이블 데이터를 확인 후 일치하는 사용자의 role(역할)을 반환하도록 구현
```
