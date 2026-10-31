# pokem

card 검수 및 대리판매, 사용자간 중고거래 플랫폼

## 처음 설치하기

Python 3.14와 Flutter 3.47.2를 설치한 뒤 저장소 루트에서:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

Python 가상환경과 전체 서버 의존성을 설치하고 Flutter 잠금 파일 기준으로 패키지를 복원합니다.
기존 `.env`는 유지하며, 없으면 예시 설정과 새 JWT 키로 생성합니다. DB 연결 정보는 각자 입력해야 합니다.
서버만 설치할 때는 `-SkipFlutter`를 추가합니다.
서버 의존성만 직접 설치하려면 `python -m pip install -r requirements.txt`를 사용합니다.
[팀원 설치·실행 안내](docs/setup.md)에 환경 설정, DB 준비 사항, Git 공유 파일을 정리했습니다.


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
- inspect CRU
```
1. 사용자가 검수할 상품 개수를 입력해 검수신청
2. 관리자가 도착한 상품을 확인하고 신청 건에 개별 검수 상품 등록
3. 관리자가 검수 시작 후 등급·판정 사유를 입력해 검수 완료
4. 신청자가 검수 결과를 확인하고 반환 또는 대리판매 선택
5. 대리판매 선택 시 관리자가 판매상품과 대리판매등록을 하나의 트랜잭션으로 생성
6. 구매자가 구매확정하면 실제 소유자인 검수신청자에게 판매대금 지급
```
- post_consign_item CR
```
ERD, DB, Table, Column 모두 수정 완료
대리판매 등록은 다음을 하나의 트랜잭션으로 처리
1. 검수가 완료됐는지 확인
2. 신청자가 대리판매를 선택했는지 확인
3. 이미 대리판매 등록된 검수 상품인지 확인
4. sell_product 생성
5. post_consign_item에 검수 코드·판매상품 코드·관리자 저장
6. 모두 성공하면 커밋
```
- 위 내용들의 FastAPI 구현 및 검증 완료

### 26.10.30

- return R,PATCH
```
검수 완료 → 사용자가 검수 결과를 확인
사용자가 반환 선택 → 선택을 저장하면서 return에 해당 검수 물품의 반환 건을 자동 생성, 중복 생성은 방지
반환 목록 조회 → 사용자는 본인 반환 건만, 매니저는 전체 반환 건을 확인
담당 매니저 배정 → 매니저가 본인을 담당자로 등록
배송 처리 → delivery에서 반환 건을 연결해 배송 일자·상태를 관리
```

- USER frontend 기능, 화면 구현
```
로그인 - login(JWT Token 기반), 
회원가입 - Register, 
홈화면 - home, 
관심상품 - wishlist, 
판매등록 - post_item, 
채팅 - chat, 
충전 - recharge,
환전 - exchange, 
구매하기 - purchase_item,
구매확정 기능 추가
본인상품은 대화하기,구매하기 버튼이 나오지 않도록 수정
검수신청 - insepction_request
검수결과 확인 후 사용자 의사표시
- 대리판매 -> 담당자가 대리판매 등록
- 반환 -> 자동으로 반환 등록

지금 검수신청 시 결제 관련 진행중

```

### 26.10.30
- FastAPI 수정
```
검수 신청 시 결제 금액 카드 개수 * 일정금액
보증금 반환 시 검수등급 존재하는 카드 개수 * 일정금액
으로 가격 API에서 안받아도 되게 수정
```

- USER frontend 기능, 화면 구현
```
검수신청 후 결제 기능

구매취소 기능
- 구매취소 후 판매자는 승인 또는 거절.
- 구매취소를 취소할 수 있음

후기 작성 조회 기능

판매자 전체 후기 조회 기능 추가(신뢰도)
- 판매자 ID 기준으로 일반판매·대리판매 후기 조회 API 확장
- 상품 상세에 판매자 후기 화면 연결
- 평균 별점·후기 수 표시

```
## 남궁인성

- manager는 등록자와 관계없이 proposal·order·receive·discard의 전체 목록과 상세를 조회할 수 있다.
  등록 담당자 확인과 director의 품의 승인 권한은 기존 규칙을 유지한다.

```
manager CR
inspection_request CRU
pay CRU
deposit_refund CR
FastAPI 구현 및 검증 완료
```

- login 시도 시 auth를 통하여 user, manager에 대해서 테이블 데이터를 확인 후 일치하는 사용자의 role(역할)을 반환하도록 구현

- 사용자가 inspection_request를 넣으면 로그인된 user_id와 수량을 적어서 보내고
  date와 no는 자동 생성된다. 이때 no는 date+{seq:06d}로 생성된다.
  추후 관리자가 확인하면 확인한 관리자의 id가 patch되어 들어간다.

- no 로 생성되는 번호들은 생성번호 길이 초과 문제로 VARCHAR로 수정

- inspection_request가 확인되면 pay가 자동 생성

- 검수 완료시 발생하면 deposit_refund가 생성

---

```
delivery CR
director CR
case CR
delivery_company CR
product_company CR
proposal CRU
order CR
receive CR
receipt CR
discard CR
FastAPI 구현 및 검증 완료
```

- delivery는 purchase_item에서 user_id와 sell_product_code를 가져오거나 return에서 user_id와 inspect_code를 가져온다.
  purchase_item_code와 return_no 중 하나만 지정하며, 같은 원본 건의 중복 배송은 허용하지 않는다.
  return_no는 inspect_code + return_date(YYYYMMDD)로 구성한다.

- manager가 director에게 proposal을 작성하면 director가 대기상태인 status를 승인 또는 반려로 바꾸고 NULL이었던 director_id를 update한다.

- proposal이 승인되면 승인된 proposal에 대해서 manager가 order를 작성할 수 있다.

- order가 생성되면 그에따라 receive도 발생하게 된다.

- receipt_no는 pay_no + receipt_date(YYYYMMDD)로 자동 생성하며, receipt_amount는 접수 수량이다.
  등록 매니저는 로그인 계정, user_id는 연결된 pay에서 가져온다.

- receipt는 현재 결제완료 여부, 검수 요청과 접수 상품의 연결 관계, 누적 접수 수량 검증이 미구현 상태다.
  추후 백엔드 service에서 검증과 저장을 같은 트랜잭션으로 처리해야 한다.
  현재 검수 요청에 상품 연결 정보가 없어, 해당 관계를 확인할 근거 데이터가 필요하다.

- discard는 현재 폐기할 상품을 등록하는 것만 할 수 있고 sell_product를 지우는 실질적 폐기는 진행하지 않고 있는 상태이다.


### 검수 물품 반환

- 대리판매 등록 시 만료일(등록 + 14일)과 매니저가 지정한 반환 배송업체를 저장합니다.
  서버가 1분마다 만료된 미판매 물품을 확인해 반환·배송준비 건을 함께 생성합니다.
  거래중·거래완료 물품은 제외하며, 만료 상품 구매와 중복 반환은 차단합니다.
  기존 등록 건은 반환 배송업체를 지정해야 합니다. [대리판매 만료 반환](docs/consignment_expiry.md)

검수완료 후 사용자가 반환을 선택하면 반환 건을 자동 접수합니다.
`GET /return`, `GET /return/{return_no}`, `PATCH /return/{return_no}/manager`를 제공합니다.
return은 반환 물품·사용자·담당자만 관리하며 배송 일자·상태는 delivery에서 관리합니다.
API 및 DB 변경 내용은 [반환 문서](docs/return.md)를 참고하세요.


### 판매상품 이미지

`POST /sell_product/image`에 로그인 토큰과 사진 한 장을 업로드하고,
응답의 `sell_product_image`를 기존 상품 등록·수정 JSON에 넣습니다.
이미지는 서버 로컬 폴더에 저장합니다. [설치 및 앱 연동 방법](docs/product_image.md)을 참고하세요.
