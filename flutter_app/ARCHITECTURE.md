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

PurchaseConfirmVm은 구매 건별 최신 상태 조회·구매확정·중복 차단·응답 유실 확인을 담당합니다.
View의 수령 확인 대화상자 이후 VM 명령을 호출하며 실제 지급 조건은 서버가 최종 검사합니다.
결과 불확실 상태를 화면 재진입 때도 유지하고 인증 변경 시 초기화합니다.
서버 구매 상태 구매확정의 거래완료 표시와 확정 가능 조건은 Purchase 모델에 정의합니다.

## 판매내역 계층

SaleRecord는 판매 유형·판매가·실제 결제 금액·일시를 정의합니다.
SalesApiService → SalesRepository → SalesVm → SalesView 순서로 기존 계층 규칙을 따릅니다.
서버의 sale_history는 일반판매·대리판매 소유 관계를 결합하고 인증된 사용자의 내역만 반환합니다.
SalesVm은 조회·재시도·인증 만료 처리를 담당하며 View는 표시·화면 이동만 처리합니다.

## 회원정보 계층

UserProfile과 ProfileInput은 조회·수정 모델입니다.
AuthApiService의 인증된 GET·PUT을 ProfileRepository가 사용하며 ProfileVm이 조회·검증·저장을 담당합니다.
ProfileView는 폼·컨트롤러·저장 결과 안내와 화면 이동을 처리합니다.
서버에서 수정 가능한 전화번호·이메일·주소만 전송합니다.

## 검수신청 계층

InspectionRequest는 신청번호·수량·신청일·담당자 모델입니다.
InspectionApiService → InspectionRepository → InspectionHistoryVm/InspectionCreateVm → View로 연결합니다.
생성 VM이 수량 검증·중복 제출·불확실 응답·401·인증 변경 시 응답 무시를 처리합니다.
View는 폼·입력 컨트롤러·신청번호 표시·화면 이동만 담당합니다.

InspectionResult는 상태·판정·사용자 선택 가능 조건을 정의합니다.
InspectionResultsVm은 신청별 결과 조회, InspectionChoiceVm은 카드별 최신 상태 확인·선택·중복 차단·응답 유실 확인을 담당합니다.
InspectionResultsView와 InspectionChoiceActions는 표시·확인 대화상자·명령 전달만 담당합니다.

검수비 조회는 InspectionFee → InspectionFeeApiService → InspectionFeeRepository → InspectionFeeVm → InspectionFeeView로 분리합니다. 관리자 전용 결제 상태 변경 API는 사용자 앱에서 호출하지 않습니다.

InspectionFeePaymentVm은 사용자 버튼으로 결제완료 상태를 기록하고 중복 제출·결과 불확실 상태·재조회·인증 변경을 처리합니다. 금액은 서버가 검사하며 외부 입금 확인이나 포켐머니 차감은 하지 않습니다.

DepositRefund 모델과 InspectionFeeApiService/Repository를 통해 결제별 환급 기록을 조회합니다. DepositRefundVm이 페이징·인증·오류를 처리하고 DepositRefundView는 기록 표시와 명령만 담당합니다.

ReturnItem → ReturnApiService → ReturnRepository → ReturnVm → ReturnView로 반환내역을 조회합니다. ReturnVm은 본인 인증·필터·페이지 상태·재시도를 관리하고 View는 반환 접수와 담당자 배정 정보만 표시합니다. 배송 처리와 분리합니다.

PurchaseCancellation과 PurchaseCancelSnapshot은 취소 정보·신청 가능 조건을 정의합니다. PurchaseCancelRepository가 구매·취소 정보를 결합하며 PurchaseCancelVm이 신청·철회·검증·응답 유실 확인을 담당합니다. View는 입력·확인 대화상자·표시만 처리합니다.

판매자 취소 요청은 SellerCancelRepository가 판매자 ID로 내역을 구분하고 SellerCancelVm이 목록 조회를 담당합니다. SellerCancelDecisionVm은 최신 상태·권한 확인·승인/거절·중복 방지·응답 유실 확인을 처리합니다. 확인 대화상자와 선택적 사유 입력은 SellerCancelView에 둡니다.

## 후기 계층

ReviewRecord와 ReviewSnapshot은 후기·최신 구매·작성 가능 조건을 정의합니다.
ReviewApiService와 기존 PurchaseApiService를 ReviewRepository가 결합해 구매별 후기를 식별합니다.
ReviewVm이 별점·내용 검증·작성·결과 확인·인증 변경을, ProductReviewsVm이 공개 상품 후기 조회를 담당합니다.
ReviewView는 폼·별점 입력·컨트롤러, ReviewCard와 ProductReviewsView는 후기 표시를 담당합니다.

판매자 후기는 ReviewApiService/ReviewRepository의 판매자별 조회를 SellerReviewsVm이 사용합니다. SellerReviewSummary가 건수와 평균을 계산하고 SellerReviewsView는 결과만 표시합니다. 일반판매·대리판매 소유자 관계 필터링은 서버 서비스가 담당합니다.

## 상품 수정 계층

ProductEditInput은 폼 입력, ProductEditDraft는 검증 후 수정 요청을 정의합니다.
ProductEditApiService → ProductEditRepository → ProductEditVm → ProductEditView로 연결합니다.
VM이 소유자·판매 유형·상태·가격 검증과 수정 후 갱신을 담당하고 View는 입력·표시·화면 이동만 처리합니다.
내 상품 관리 목록은 SalesView의 관리 모드로 기존 SalesVm 조회를 재사용합니다.

상품 수정 사진 교체는 ProductEditVm이 기존 ProductPhotoPicker와 ProductPublishRepository.uploadPhoto를 조합합니다. 선택 사진·업로드 주소·선택 진행·오류는 ProductEditState가 보관하고 ProductEditView는 미리보기와 입력 명령만 처리합니다. 저장 재시도 시 업로드 주소를 재사용합니다.


- 취소 승인: SellerCancelDecisionVm에서 승인 결과를 반영하고 상품 상세·홈·관심상품·판매내역을 갱신합니다. 서버의 승인 트랜잭션에서 환불과 상품 판매중 복구를 함께 처리합니다.

- 배송 조회: DeliveryView → DeliveryVm → DeliveryRepository → DeliveryApiService. 구매번호/반환번호를 family 키로 사용하며 사용자 변경 시 다시 조회합니다. 저장소에서 전체 페이지를 순서대로 검색하고 상세 응답의 원본 번호와 소유자를 검증합니다. 배송 처리 로직은 서버에 유지합니다.

- 대리판매 상세: ConsignmentView → ConsignmentVm → ConsignmentRepository → ConsignmentApiService/ProductRepository. 검수번호 또는 등록번호를 family 키로 사용하며, 저장소에서 등록 소유자·원본 연결·상품 소유자와 대리판매 유형을 확인합니다. 상품 조회 실패는 등록 정보와 별도로 표시합니다.

- 회원탈퇴: QuitView → QuitVm → QuitRepository → QuitApiService. 확인·중복 방지·불명확한 결과는 VM에서 관리합니다. 세션별 VM 상태를 유지하며 계정 변경 시 초기화하고, 서버의 성공 응답 확인 후 LoginVm에서 세션을 정리합니다.

- 회원탈퇴 서버 판정: user 행과 거래 관계를 보존하고 quit의 user_user_id 존재 여부로 활성 계정을 판단합니다. 공통 JWT 인증과 별도 WebSocket 인증·메시지 저장 경로에 동일한 탈퇴 판정을 적용합니다.
