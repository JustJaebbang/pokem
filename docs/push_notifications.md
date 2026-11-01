# Android 검수 완료 푸시 알림

현재 범위는 **검수 완료**입니다. 일반 검수 완료 처리와 등급을 지정한 검수 즉시 등록에 연결했습니다. 취소·환불·채팅 푸시는 아직 연결하지 않았습니다. 기존 앱 내 종 모양 알림함과 조회 API는 유지합니다.

## Firebase 프로젝트 준비

1. [Firebase Console](https://console.firebase.google.com/)에서 프로젝트를 만듭니다. FCM을 위해 Firebase Authentication이나 Firestore로 기존 시스템을 바꿀 필요는 없습니다.
2. 프로젝트에 **Android 앱**을 추가합니다. Android 패키지명은 `com.pokem.pokem_app`입니다. FCM을 위한 SHA 인증서 등록은 필요하지 않습니다.
3. 내려받은 클라이언트 설정 `google-services.json`을 `flutter_app/android/app/google-services.json`에 둡니다. 해당 앱과 아래 서버 발송 자격 증명은 같은 Firebase 프로젝트를 사용합니다.
4. Firebase 프로젝트 설정 → 서비스 계정에서 서버용 비공개 키를 발급받아 저장합니다. 예: 저장소 루트의 `.secrets/firebase-adminsdk.json`. 이 파일은 **서버에서만 사용**하고 Flutter assets·앱·Git·채팅에 넣지 않습니다.
5. Firebase Cloud Messaging API(HTTP v1)가 활성화되어 있는지 확인합니다. 발송 계정에는 해당 프로젝트 메시지 발송 권한이 필요합니다.

클라이언트 `google-services.json`과 서버 서비스 계정 비공개 키는 역할이 다른 파일입니다. 둘 다 현재 Git에서는 제외합니다. Firebase SDK와 Google Services 플러그인은 이미 프로젝트에 추가했습니다. 설정 파일이 없으면 플러그인을 적용하지 않으므로 기존 앱 빌드가 유지됩니다.

## Firebase 콘솔의 “Firebase SDK 추가” 단계

이 단계에 표시되는 Kotlin/Java용 Gradle 코드는 **현재 프로젝트에 다시 붙여 넣지 않습니다.** 우리 앱은 Flutter이고 아래 설정을 이미 적용했습니다. 콘솔에서는 해당 단계를 확인한 뒤 **다음 → 콘솔로 이동**으로 진행하면 됩니다. 화면 문구는 콘솔 버전에 따라 다를 수 있습니다.

| 콘솔에서 안내하는 작업 | 현재 프로젝트의 처리 |
|---|---|
| Google Services Gradle 플러그인 버전 등록 | `flutter_app/android/settings.gradle.kts`에 등록 완료 |
| Android 앱에 Google Services 플러그인 적용 | `flutter_app/android/app/build.gradle.kts`에서 설정 파일이 있으면 적용하도록 구현 완료 |
| Firebase SDK 의존성 추가 | `flutter_app/pubspec.yaml`에 `firebase_core`, `firebase_messaging` 추가 완료. Flutter 플러그인이 Android SDK 의존성을 연결 |
| Firebase 초기화 | `PushMessagingService.initialize()`에서 처리. Android 푸시 활성화 상태의 사용자 세션에서 호출 |

따라서 지금 직접 할 작업은 다음과 같습니다.

1. 콘솔에서 다운로드한 파일 이름을 **정확히 `google-services.json`**으로 맞춥니다. `google-services (1).json` 같은 이름이면 변경합니다.
2. 프로젝트 루트가 아니라 **`flutter_app/android/app/`** 폴더에 둡니다.

```text
pokem/
  flutter_app/
    android/
      app/
        build.gradle.kts
        google-services.json  ← 여기에 배치
        src/
```

3. Firebase에 등록한 Android 패키지명이 **`com.pokem.pokem_app`**인지 확인합니다. 다른 패키지의 설정 파일이라면 Firebase 콘솔에서 올바른 Android 앱을 등록하고 다시 다운로드합니다.
4. 콘솔의 SDK 추가 단계는 다음으로 넘어갑니다. **Firebase BoM, `firebase-analytics`, 네이티브 `firebase-messaging` 의존성을 수동으로 추가할 필요는 없습니다.** 현재 Flutter 플러그인이 필요한 SDK를 관리합니다.
5. VS Code 터미널에서 아래 명령을 실행합니다. 먼저 FastAPI 서버는 기존처럼 실행해 두고, 아래에서 앱만 실행합니다.

```powershell
# 저장소 루트에서 실행
cd flutter_app
flutter pub get
flutter run --dart-define=PUSH_ENABLED=true --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

설정 파일을 추가한 뒤에는 **앱 실행을 완전히 종료하고 다시 실행**합니다. Hot Reload만으로는 Android Gradle 설정이 적용되지 않습니다. 정상 실행 중 Gradle 캐시 관련 오류가 난 경우에만 `flutter clean`, `flutter pub get` 후 다시 실행합니다.

이것은 **휴대폰 앱 쪽 SDK 설정**입니다. 여기까지 했다고 서버가 알림을 발송할 수 있는 것은 아닙니다. 아래의 서버 서비스 계정·환경변수 설정도 완료해야 합니다. `google-services.json` 대신 서비스 계정 비공개 키를 Android 폴더에 넣으면 안 됩니다.

현재 프로젝트는 `google-services.json`으로 Android 기본 Firebase 앱을 초기화하므로, 이 절차에서 `flutterfire configure` 실행이나 `firebase_options.dart` 수동 생성은 필요하지 않습니다. 추후 iOS·웹을 추가하거나 초기화 방식을 변경하면 별도로 구성합니다.

참고: [Flutter Firebase 설정](https://firebase.google.com/docs/flutter/setup), [Android Firebase 설정](https://firebase.google.com/docs/android/setup).

## DB 및 서버

현재 연결 DB에는 신규 테이블 두 개를 적용했습니다. 기존 업무 데이터는 변경하지 않았으며 적용 전 스키마 메타데이터는 `.rollback/fcm-schema-*`에 보관했습니다. 다른 DB를 사용하는 경우 `sql/push_notifications.sql`을 적용합니다. MySQL 8 이상을 대상으로 합니다.

- `push_device`: 설치 식별자·사용자·계정 연결 식별자·FCM FID·갱신 시각. 사용자 한 명이 여러 기기를 등록할 수 있습니다.
- `push_outbox`: 검수 완료 이벤트별 기기 발송 대기·시도 횟수·재시도 시각·작업 임대. 기존 업무 테이블과 사용자 데이터는 변경하지 않습니다.

`.env.example`의 항목을 로컬 `.env`에 설정하고 서버를 재시작합니다.

```dotenv
PUSH_ENABLED=true
GOOGLE_APPLICATION_CREDENTIALS=C:/absolute/path/to/.secrets/firebase-adminsdk.json
```

SDK는 `requirements.txt`에 잠겨 있습니다. 기존 설치 스크립트 또는 아래 명령으로 설치합니다.

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

**Firebase·DB 설정 전에는 `PUSH_ENABLED=false`를 유지합니다.** Firebase 발송 설정이 잘못되면 작업은 재시도 후 실패 상태가 되므로, 설정을 먼저 확인한 뒤 활성화합니다.

## Flutter 실행

```powershell
cd flutter_app
flutter pub get
flutter run --dart-define=PUSH_ENABLED=true --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

앱의 `--dart-define=PUSH_ENABLED`와 서버 `.env`의 `PUSH_ENABLED`는 별도 설정입니다. 기본값은 둘 다 비활성입니다. 변경 후 전체 재실행·재빌드가 필요합니다. 이번 연결은 Android만 지원합니다.

사용자로 로그인한 후 마이페이지의 **검수 푸시 알림**을 켜고 Android 알림 권한을 허용합니다. 권한을 거절했다면 시스템 앱 알림 설정에서도 허용해야 할 수 있습니다. Android 알림 채널 이름은 검수 알림입니다. Google Play 서비스를 지원하는 기기 또는 Google APIs/Google Play 에뮬레이터를 사용합니다.

## 연결 API

- `PUT /push/devices/{installation_id}`: 로그인한 사용자에게 기기 등록. 본문 `{"fid":"SDK 등록 이벤트의 FID"}`. 사용자 ID를 요청 본문으로 받지 않습니다.
- `DELETE /push/devices/{installation_id}`: 본인에게 연결된 기기만 해제.
- 설치 식별자는 앱의 secure storage에 보관합니다. 새 FID·앱 재개·로그인 시 갱신하고, 로그아웃·탈퇴·알림 끄기에서는 서버 해제와 SDK 등록 해제를 시도합니다.
- 계정 전환 시 연결 식별자를 바꿔 이전 계정으로 대기하던 알림을 새 계정에 보내지 않습니다. 발송 직전에 탈퇴 여부도 확인합니다.

MVVM 흐름은 View → Riverpod PushVm → PushRepository → PushMessagingService/PushDeviceService입니다. View는 Firebase SDK나 HTTP에 직접 접근하지 않습니다.

## 발송·수신 동작

1. 서버에서 검수를 완료하면 **같은 DB 트랜잭션** 안에서 현재 등록 기기별 발송 대기를 저장합니다. 당시 등록 기기가 없는 사용자에게는 과거 검수 완료 푸시를 나중에 소급 발송하지 않습니다.
2. 별도 작업이 5초 간격으로 발송 대기를 확인합니다. Firebase 네트워크 호출은 검수 트랜잭션 밖에서 수행합니다. 재시도는 최대 5회이며 기본 대기 시간은 30초부터 증가합니다.
3. DB 기록 실패는 트랜잭션을 롤백합니다. 기록 후 Firebase 전송 실패는 이미 완료된 검수 상태를 되돌리지 않습니다. 검수 기능을 중단 없이 유지하려면 설정 전 푸시를 비활성으로 둡니다.
4. 백그라운드에서는 Android 시스템 알림, 앱 사용 중에는 안내 메시지와 보기 버튼을 표시합니다. 알림을 누르면 검수 결과 화면으로 이동합니다. 앱이 종료된 상태의 클릭은 로그인 완료 후 처리합니다.
5. 수신 데이터의 대상 사용자·알려진 화면 종류·신청번호 형식을 검사하고, 실제 검수 결과 조회도 기존 서버 권한 검사를 거칩니다. 판정 사유는 알림 내용이나 데이터에 넣지 않습니다.

전송 방식은 최소 한 번 시도 방식이므로 네트워크 경계에서 완벽한 1회 전달을 보장하지 않습니다. 이벤트 키·기기별 중복 기록 방지, Android 알림 태그, 앱 내 이벤트 중복 검사로 중복을 줄입니다. `sent`는 FCM 접수 성공이며 사용자가 실제로 읽었다는 뜻은 아닙니다. 푸시 클릭을 기존 알림함의 읽음으로 자동 기록하지는 않습니다.

## 실제 수신 확인

1. 본인 테스트 계정으로 로그인하고 권한·기기 등록을 완료합니다.
2. 앱을 백그라운드로 보냅니다.
3. 담당자 테스트 계정에서 그 사용자의 카드를 검수 완료 처리합니다.
4. 알림창에 검수 완료 안내가 나타나고, 클릭하면 해당 신청의 검수 결과로 이동하는지 확인합니다.
5. 앱 실행 중 안내, 로그아웃·계정 전환 후 이전 사용자 화면 차단도 확인합니다.

Firebase 프로젝트가 아직 없어서 실제 발송·수신은 검증하지 않았습니다. 모의 SDK·격리 DB 테스트로 발송 대기 원자성, 재시도, 계정 전환, 탈퇴·무효 기기 제외, 화면 이동을 검증합니다. 서버에서는 자격 증명·FID·SDK 오류 전문을 로그에 남기지 않습니다.

Android 설정에서 앱을 강제 종료한 경우 다시 열기 전에는 수신이 제한될 수 있습니다. 앱 알림 권한·채널 설정·네트워크도 실제 표시 여부에 영향을 줍니다. 로그아웃 시 네트워크가 없으면 서버 해제가 실패할 수 있어 SDK 해제도 함께 시도합니다. 두 작업 모두 실패하면 즉시 원격 해제를 보장하지 못하므로 알림 문구는 개인정보 없는 일반 안내로 제한합니다.

참고: [Flutter FCM 설정](https://firebase.google.com/docs/cloud-messaging/flutter/get-started), [수신·권한·앱 상태](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [Firebase Admin SDK](https://firebase.google.com/docs/admin/setup).
