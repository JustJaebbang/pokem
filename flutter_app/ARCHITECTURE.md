# MVVM + Riverpod

앱은 계층별 폴더(model, view, vm, repository, service) 안에서 기능을 구분합니다.
View → VM → Repository → Service 순서로 처리하며 각 계층에서 Model을 사용합니다.

| 계층 | 책임 | 금지하는 의존성 |
| --- | --- | --- |
| view | 표시, 입력 전달, 컨트롤러·키보드·화면 이동 | repository, service, 데이터 Provider 직접 호출 |
| vm | 입력 검증·변환, 화면 상태, 비동기 작업, 처리 흐름 | view, BuildContext, Navigator |
| repository | 데이터 처리 정책, 세션·저장 관리 | view, vm, Riverpod |
| service | HTTP 통신, 사진 선택 등 플랫폼 접근 | view, vm, Riverpod |
| model | 데이터 구조와 직렬화 | view, vm, Riverpod |
| core/providers | Service·Repository·보안 저장소 의존성 조립 | 화면 로직 |

## 화면별 VM

- LoginVm: 로그인 입력 검증, 인증·자동로그인·로그아웃·토큰 만료
- RegisterVm: 회원가입 입력 검증, 비밀번호 확인, 요청 모델 구성·등록
- HomeShellVm: 하단 탭 선택, 상품 등록 후 홈 선택
- ProductsVm: 상품 조회·검색·판매중 조건·새로고침을 하나의 화면 상태로 관리
- ProductDetailVm: 상세 조회·재시도, 사용자 역할 및 상품 상태에 따른 동작 가능 여부
- WishlistVm: 내 관심 조회·등록·해제, 요청 중복 방지, 실패 상태 보존·로그아웃 응답 무시
- ProductCreateVm: 사진 선택·오류, 상품 입력 검증·가격 변환, 업로드·등록·성공 후 목록 갱신

`vm/<기능>/state`는 화면에 필요한 상태를 정의합니다. Riverpod Notifier가 상태를 변경합니다.
View의 Form validator는 VM 검증 메서드에 위임하며 가격 변환·이메일 정규식 등의 판단을 포함하지 않습니다.
입력 모델과 API 요청 모델을 분리합니다. 비밀번호와 가격 문자열은 View가 임의 변환하지 않습니다.
화면 이동·SnackBar·TextEditingController는 UI 책임이므로 View에 둡니다.
숫자 키보드·입력 포맷터·표시용 금액 형식도 UI 책임입니다.
VM은 Widget이나 화면 클래스를 참조하지 않습니다.

## 검증

flutter analyze, flutter test, flutter build apk --debug로 확인합니다.
MVVM 경계 테스트는 View의 데이터 계층 접근과 데이터 계층의 Riverpod 의존을 검사합니다.
직접 VM을 호출해 잘못된 입력이 API에 도달하지 않는지도 확인합니다.

관심상품 코드와 상품 목록의 결합은 WishlistRepository에서 담당합니다. 상세 하트와 관심 탭은 WishlistVm의 상태를 공유하며, View는 Repository나 Service를 직접 호출하지 않습니다.

## 채팅 계층

model/chat에 방·메시지·오류 모델을 둡니다.
service/chat은 HTTP와 네이티브 WebSocket을, repository/chat은 데이터 접근을 제공합니다.
ChatStartVm은 상품 문의 방 생성·재사용, ChatRoomsVm은 목록·더 보기,
ChatRoomVm은 인증·연결·이력·메시지 병합·전송 확인·재연결·종료 정리를 담당합니다.
view/chat은 목록과 말풍선·입력·스크롤을 표시하고 VM 명령만 호출합니다.
화면 입력은 서버 저장 확인 이벤트를 VM이 상태로 통지한 뒤 비웁니다.

## 구매 계층

model/purchase는 회원 잔액·구매 기록·오류를 정의합니다.
PurchaseApiService는 인증된 회원 조회·구매·구매내역 HTTP 요청을,
PurchaseRepository는 최신 상품과 회원 정보를 결합합니다.
CheckoutVm은 결제 가능 조건·동의·중복 제출 차단·응답 유실 확인·완료 후 갱신을 담당합니다.
PurchaseHistoryVm은 내 구매내역 조회·재시도·401 처리를 담당합니다.
View는 VM 상태와 명령만 사용하며 요청·금액 판정을 직접 수행하지 않습니다.

## 지갑 계층

model/wallet은 충전·환전 구분, 내역, 잔액 응답과 오류를 정의합니다.
WalletApiService는 기존 회원·충전·환전 API를 호출하고 WalletRepository는 두 종류의 내역을 합칩니다.
WalletVm은 잔액·내역 조회, MoneyTransferVm은 입력·한도 검증, 중복 요청 차단과 결과 보존을 담당합니다.
전송 VM은 같은 세션의 화면 재진입 시 불확실한 요청을 반복하지 않도록 유지하고 인증 변경 시 초기화합니다.
View는 입력 컨트롤러·확인 대화상자·화면 이동을 처리하며 API에 직접 접근하지 않습니다.
