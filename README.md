# pokem

card 검수 및 대리판매, 사용자간 중고거래 플랫폼

## 허재영

user CRUD - D user의 판매상품이나 참조하는 부분에 대한 CASCADE 설정 결정해야함
sell_product CRU - 로그인 기능 구현하면 C user_id 부분 수정해야함
post_item CR
wishlist CRD
purchase_item CR
recharge CR
login
FastAPI 구현 및 검증 완료


## 남궁인성

manager CR
inspection_request CRU
pay CRU
deposit_refund CR
FastAPI 구현 및 검증 완료

- login 시도 시 auth를 통하여 user, manager에 대해서 테이블 데이터를 확인 후 일치하는 사용자의 role(역할)을 반환하도록 구현

- 사용자가 inspection_request를 넣으면 로그인된 user_id와 수량을 적어서 보내고
  date와 no는 자동 생성된다. 이때 no는 date+{seq:06d}로 생성된다.
  추후 관리자가 확인하면 확인한 관리자의 id가 patch되어 들어간다.

- _no 로 생성되는 번호들은 생성번호 길이 초과 문제로 VARCHAR로 수정

- inspection_request가 확인되면 pay가 자동 생성
