# 팀원 환경 설치

## 준비할 프로그램

- Python 3.14.x: Windows에서 3.14.6으로 검증했습니다. `.python-version`에 기준 버전을 기록했습니다.
- Flutter 3.47.2: Dart는 Flutter에 포함된 버전을 사용합니다. flutter/bin을 PATH에 추가합니다.
- Android 실행은 Android Studio·Android SDK·에뮬레이터 또는 실제 기기가 필요합니다.
- iOS 실행은 macOS·Xcode·서명 설정이 필요합니다. Windows에서는 iOS를 빌드할 수 없습니다.
- MySQL 서버와 이 프로젝트에 맞는 스키마·연결 정보는 팀에서 별도로 준비합니다.

Python·Flutter SDK 자체와 DB를 이 스크립트가 설치하거나 변경하지는 않습니다.

## Windows: 한 번에 설치

저장소를 받은 뒤 루트에서 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

이 명령은 이 프로세스에서만 PowerShell 실행 정책을 적용하며 시스템 정책을 변경하지 않습니다.

스크립트는 다음을 처리합니다.

1. Python 버전 확인 후 `.venv` 생성, 이미 있으면 해당 가상환경 사용
2. `requirements.txt`의 고정 버전 설치 및 `pip check`
3. `.env`가 없으면 `.env.example`을 바탕으로 생성하고 무작위 JWT 키 설정
4. 기존 `.env`는 내용 변경 없이 유지
5. FastAPI import와 Asia/Seoul 시간대 데이터 확인
6. Flutter 버전 확인 후 `flutter pub get --enforce-lockfile`

백엔드 담당자라면 Flutter 없이 실행할 수 있습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -SkipFlutter
```

Python 실행 파일을 지정해야 한다면:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -PythonCommand "C:\Python314\python.exe"
```

설치 후 IDE의 Python 인터프리터도 `.venv/Scripts/python.exe`로 선택합니다.
이미 다른 Python 버전으로 만든 `.venv`가 있으면 새 가상환경을 준비해야 합니다. 스크립트는 기존 환경을 자동 삭제하지 않습니다.

## 환경 설정과 실행

로컬 `.env`의 DB_HOST·DB_PORT·DB_USER·DB_PASSWORD·DB_NAME을 팀 환경에 맞춥니다.
JWT_SECRET_KEY는 32바이트 이상이어야 하며 실제 `.env`를 Git이나 채팅에 공유하지 않습니다.
같은 서버를 여러 프로세스로 실행한다면 서버의 JWT 키를 일관되게 설정해야 합니다.

루트에서 FastAPI 실행:

```powershell
.\.venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8000 --workers 1
```

채팅 실시간 전달이 프로세스 메모리를 사용하므로 현재는 worker를 하나 사용합니다.
Swagger는 `http://localhost:8000/docs`에서 확인합니다.
이 설치는 DB 테이블 생성·마이그레이션·테스트 데이터 생성을 수행하지 않습니다.
DB 스키마 SQL은 현재 Git 제외 대상이므로, 새 DB를 쓸 팀원은 별도로 승인된 스키마와 적용 순서를 받아야 합니다.

다른 터미널에서 앱 실행:

```powershell
cd flutter_app
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

10.0.2.2는 Android 에뮬레이터용입니다. 실제 폰은 같은 네트워크의 개발 PC IP로 바꿉니다.
서버 방화벽·포트 접근과 DB 연결은 각 환경에서 확인해야 합니다.
상품 이미지 폴더 uploads/products는 로컬 파일이며 Git에 공유되지 않습니다. 기존 DB의 이미지까지 보여야 하면 해당 파일도 별도로 전달합니다.

## 의존성 파일

| 파일 | 역할 |
| --- | --- |
| requirements.in | 직접 사용하는 Python 패키지와 기준 버전 |
| requirements.txt | 깨끗한 가상환경에서 확정한 직접·간접 의존성 고정 버전 |
| requirements-security/chat/images.txt | 이전 설치 명령 호환용, 통합 requirements.txt를 참조 |
| .python-version | 검증한 Python 버전 |
| flutter_app/pubspec.yaml | Flutter 직접 의존성 |
| flutter_app/pubspec.lock | 앱의 정확한 패키지 버전, Git 공유 필수 |
| flutter_app/.fvmrc | 팀 Flutter SDK 버전, FVM 사용 시 적용 |
| .env.example | 비밀값 없는 로컬 설정 예시 |

Python 잠금은 Windows/Python 3.14.6에서 검증했습니다. uvicorn[standard]의 OS별 추가 패키지는 각 OS에서 해결되므로 macOS/Linux는 별도 검증이 필요합니다.
Flutter SDK가 다르면 스크립트가 경고합니다. 재현성을 위해 3.47.2를 사용하는 것을 권장합니다.
FVM은 선택 사항이며 스크립트가 설치하지 않습니다. 사용한다면 flutter_app에서 fvm install 후 fvm flutter 명령을 사용합니다.

버전 변경은 requirements.in 수정 → 새 가상환경에서 설치·검증 → requirements.txt 갱신 순서로 합니다.
Anaconda나 개인 전역 환경의 pip freeze를 저장소에 그대로 덮어쓰지 않습니다.
Flutter 의존성 변경 후 pubspec.yaml과 pubspec.lock을 함께 커밋합니다.

## 검증

```powershell
.\.venv\Scripts\python.exe -m pip check
.\.venv\Scripts\python.exe -m unittest discover -s tests
cd flutter_app
flutter analyze
flutter test
```

Python 테스트 일부는 JWT 키가 필요합니다. `.env`에 정상적인 키가 있는 상태에서 실행합니다.
설치 검증 시에는 프로세스 내부 임시 키와 가짜 DB를 사용했습니다. 실제 DB 자격 증명을 검증했다는 뜻은 아닙니다.

## Git에 공유할 파일

설치 스크립트·requirements 파일·버전 파일·.env.example·문서·Flutter 잠금 파일은 커밋합니다.
실제 .env·.venv·Flutter 캐시/빌드 결과·uploads는 제외합니다.
