# pokem

card 검수 및 대리판매, 사용자간 중고거래 플랫폼

## 허재영

### 26.10.27~28

- user CRUD - D user의 판매상품이나 참조하는 부분에 대한 CASCADE 설정 결정해야함
- sell_product CRU - 로그인 기능 구현으로 C user_id 부분 수정완료
- post_item CR

```
user가 sell_product 판매 등록(post_item)시 DB에 sell_product 생성 -> post_item 생성 후 commit 트랜잭션 구현 및 검증 완료
```

- wishlist CRD
- purchase_item CR

```
user가 sell_product 구매시 구매 기록과 거래중 상태를 함께 저장. 거래완료일은 구매확정 시 기록
구매 시 상품 행 잠금으로 같은 상품의 동시 구매를 막음
```

- recharge CR
- login

```
login - 실제 user_id, user_passward 검증 후 jwt 토큰 발급하여 Authorization 구현 및 검증 완료
토큰별(role) 인증된 API만 사용 가능하게 구현
```

- 위 내용들의 FastAPI 구현 및 검증 완료

### 26.10.29

- cybermoney_pay CR

```
purchase_item 생성 시 cybermoney_pay가 하나의 트랜잭션으로 작동하게 구현 및 검증 완료
```

- purchase_item/{purchase_item_code}/confirm (구매확정) API

```
user가 구매확정(app에서) 시 API 실행하여 아래 과정 구현 및 검증 완료

1. 로그인한 사용자가 해당 구매자인지 확인
2. 결제 완료 여부와 아직 구매확정되지 않았는지 확인
3. 관련 행을 잠근 뒤 실제 결제 금액을 판매자 잔액에 추가
4. cybermoney_give에 지급 기록 저장
5. post_item_complete_date에 완료일 저장
6. sell_product_sell_status를 판매완료로 변경
7. 전부 성공하면 커밋, 하나라도 실패하면 전체 롤백
```

- review CR

```
user가 review 작성 시 아래 과정 확인

1. 로그인한 사용자가 해당 구매 기록의 구매자인지 확인
2. 연결된 판매등록에 post_item_complete_date가 있는지 확인 -> 거래완료 상품인지 확인
3. 해당 구매 건에 이미 리뷰가 작성되어 있는지 확인 -> 중복 작성 불가
```

- purchase_cancel CR

```
구매자가 취소 요청 (구매자인지 확인)
서버가 구매확정 전인지 확인하고 취소요청으로 기록
판매자가 물품 전달·반환 여부를 확인한 뒤 승인 또는 거절 | 또는 구매자가 결제취소를 취소

판매자가 승인 -> 구매자 잔액 반환·결제취소·구매취소를 하나의 트랜잭션으로 처리

판매자가 거절 -> 구매자는 구매확정 또는 미응답(이 부분에 대해서 후처리가 좀 더 필요하다고 생각함. 신고하기를 만든다거나 관리자의 개입이 있어야 될 것 같기도 하고 등등)

구매자가 결제취소를 취소 -> 구매자가 구매확정
```

- Websocket 기반 chat_room, chat CR 구현 및 검증 완료

```
ERD,DB 각 테이블의 컬럼 및 참조 관계 수정
지금은 http기반 채팅. 이제 http기반으로 websocket으로 구현할 것

로그인한 사용자를 문의자로 설정
상품의 post_item에서 판매자 확인
본인 상품에 채팅을 여는 요청은 차단
해당 상품·문의자의 방이 있으면 반환
없으면 상품·문의자·판매자를 저장해 생성

현재 websocket으로 구현 및 검증 완료
문의자, 판매자 각각의 token과 같은 chat_room_id를 사용하면 연결 할 수 있다.
이후 메시지 전송 시 동시에 발생
```
- 위 내용들의 FastAPI 구현 및 검증 완료

## 남궁인성

manager CR
inspection_request CRU
pay CRU
deposit_refund CR

---

delivery CR
director CR
case CR
delivery_company CR
product_company CR
FastAPI 구현 및 검증 완료

- login 시도 시 auth를 통하여 user, manager에 대해서 테이블 데이터를 확인 후 일치하는 사용자의 role(역할)을 반환하도록 구현

- 사용자가 inspection_request를 넣으면 로그인된 user_id와 수량을 적어서 보내고
  date와 no는 자동 생성된다. 이때 no는 date+{seq:06d}로 생성된다.
  추후 관리자가 확인하면 확인한 관리자의 id가 patch되어 들어간다.

- no 로 생성되는 번호들은 생성번호 길이 초과 문제로 VARCHAR로 수정

- inspection_request가 확인되면 pay가 자동 생성

- 검수 완료시 발생하면 deposit_refund가 생성

- delivery는 pruchase_item 데이블을 통해 user_id와 sell_product_code를 가져온다.
