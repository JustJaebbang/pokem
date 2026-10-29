# 포켐 앱

Flutter 클라이언트 앱입니다. FastAPI 백엔드와 별도 디렉터리에서 관리합니다.

## 실행

Flutter SDK가 설치된 환경에서:

```sh
cd app
flutter pub get
flutter run
```

기본 API 주소는 저장소의 현재 FastAPI 호스트인 `http://192.168.10.36:8000`입니다.
다른 기기나 네트워크에서 실행할 때는 접근 가능한 백엔드 주소를 지정하세요.

```sh
flutter run --dart-define=API_BASE_URL=http://<백엔드-호스트>:8000
```

상품 사진은 갤러리나 카메라에서 선택하고, 기기에서 최대 720px·품질 45로 줄인 뒤 JPEG/PNG/WebP data URI로 기존 `sell_product_image` 필드에 저장합니다. 이 방식은 `/uploads/...` 정적 파일 경로에 의존하지 않습니다. DB 이미지 컬럼은 약 62KB의 문자열을 저장할 수 있어야 하며, 컬럼 길이가 더 짧다면 프론트엔드만으로 영구 사진 저장을 보장할 수 없습니다. 이전 `/uploads/products/...` 값은 서버에 파일이 없어 앱에서 자리표시자로 표시합니다.

상품 목록은 공개 `GET /sell_product`를 사용하고, 로그인·찜·상품 등록·구매 요청은 각 API의 bearer 토큰 인증을 사용합니다.

내 정보의 결제 내역은 `GET /cybermoney_pay`와 `GET /cybermoney_pay/{code}`를 사용합니다. 화면에서는 결제 코드 형식 `구매코드_결제일시`를 표시하고, 서버 상태값 `결제완료`는 `결제 성공`으로 보여줍니다.

판매자 지급 영수증은 구매자가 구매를 확정할 때 기존 응답에서 `cybermoney_give_code`, 지급액, 판매자 ID를 읽어 표시합니다. 현재 백엔드에는 지급 내역 목록·상세 조회 경로가 없어 과거 지급 목록은 프론트에서 불러올 수 없습니다.

## 구조

- `lib/main.dart`: Material 3 앱 테마와 시작 화면
- `lib/api_config.dart`: 빌드별 API 기본 주소
- `pubspec.yaml`: Flutter 패키지 및 개발 도구 의존성

API 주소와 연동 계층은 실제 실행 환경에 맞춰 별도 설정할 수 있습니다. 비밀 키나 데이터베이스 접속 정보를 앱에 넣지 마세요.
