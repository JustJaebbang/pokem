# pokem

card 검수 및 대리판매, 사용자간 중고거래 플랫폼

## 허재영

user CRUD
sell_product CRU
post_item CR
FastAPI 구현 및 검증 완료

user가 sell_product 판매 등록(post_item)시 DB에 sell_product 생성, post_item 생성 후 commit 트랜잭션 구현

## 남궁인성

manager CR
inspection_request CRU
pay CRU
deposit_refund CR
delivery CR
FastAPI 구현 및 검증 완료

- login 시도 시 auth를 통하여 user, manager에 대해서 테이블 데이터를 확인 후 일치하는 사용자의 role(역할)을 반환하도록 구현

- 사용자가 inspection_request를 넣으면 로그인된 user_id와 수량을 적어서 보내고
  date와 no는 자동 생성된다. 이때 no는 date+{seq:06d}로 생성된다.
  추후 관리자가 확인하면 확인한 관리자의 id가 patch되어 들어간다.

- \_no 로 생성되는 번호들은 생성번호 길이 초과 문제로 VARCHAR로 수정

- inspection_request가 확인되면 pay가 자동 생성

- 검수 완료시 발생하면 deposit_refund가 생성

- delivery는 pruchase_item 데이블을 통해 user_id와 sell_product_code를 가져온다.
