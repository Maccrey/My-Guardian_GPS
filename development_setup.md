# GPS Search - 개발 환경 설정

## 필수 도구

- Flutter SDK: 최신 안정 버전
- Dart SDK: Flutter SDK에 포함된 버전
- Android Studio 또는 VS Code: Flutter 플러그인 설치
- Git: 버전 관리
- Firebase CLI: Firebase 프로젝트 관리

## 개발 환경 설정

### 1. Flutter 설정

```bash
# Flutter 설치 확인
flutter doctor

# Flutter 최신 버전으로 업데이트
flutter upgrade

# 필요한 패키지 설치
flutter pub get
```

### 2. Firebase 프로젝트 설정

1. [Firebase 콘솔](https://console.firebase.google.com/)에서 새 프로젝트 생성
2. Flutter 앱 등록 (Android & iOS)
3. `google-services.json` 및 `GoogleService-Info.plist` 파일 다운로드
4. 프로젝트 디렉토리의 적절한 위치에 파일 배치
5. Firebase CLI 설정

```bash
# Firebase CLI 설치
npm install -g firebase-tools

# Firebase 로그인
firebase login

# Flutter Fire CLI 설치
dart pub global activate flutterfire_cli

# Firebase 초기화
flutterfire configure
```

## 주요 의존성 패키지

GPS Search 앱은 다음 주요 패키지를 사용합니다:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 상태 관리
  get: ^4.6.6

  # Firebase
  firebase_core: ^2.22.0
  firebase_auth: ^4.14.0
  cloud_firestore: ^4.13.1
  firebase_messaging: ^14.7.4
  firebase_storage: ^11.5.1

  # 위치 서비스
  geolocator: ^10.1.0
  google_maps_flutter: ^2.5.0
  flutter_local_notifications: ^16.1.0

  # UI 및 유틸리티
  intl: ^0.20.0
  flutter_svg: ^2.0.9
  shared_preferences: ^2.2.2
  url_launcher: ^6.2.1 # 전화 기능 사용
  permission_handler: ^11.0.1
  connectivity_plus: ^5.0.1

  # 백그라운드 처리
  workmanager: ^0.5.1
  background_fetch: ^1.2.1
```

## 안드로이드 설정

### AndroidManifest.xml 권한 설정

```xml
<manifest ...>
    <!-- 인터넷 권한 -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- 위치 권한 -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

    <!-- 백그라운드 서비스 관련 권한 -->
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />

    <!-- 알림 권한 -->
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

    <!-- 전화 권한 -->
    <uses-permission android:name="android.permission.CALL_PHONE" />

    <!-- 배터리 최적화 무시 권한 (백그라운드 위치 추적용) -->
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

    <application ...>
        <!-- Google Maps API 키 설정 -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_API_KEY" />

        <!-- FCM 설정 -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="high_importance_channel" />

        <!-- 백그라운드 작업 설정 -->
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

## iOS 설정

### Info.plist 권한 설정

```xml
<dict>
    <!-- 위치 권한 -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>앱이 위치 정보를 사용하여 위치 공유 기능을 제공합니다.</string>
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>귀가 알림 및 SOS 기능을 위해 백그라운드 위치 정보가 필요합니다.</string>
    <key>NSLocationAlwaysUsageDescription</key>
    <string>위치 공유 기능을 위해 백그라운드 위치 정보가 필요합니다.</string>

    <!-- 푸시 알림 설정 -->
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
        <string>fetch</string>
        <string>processing</string>
        <string>location</string>
    </array>

    <!-- 전화 권한 -->
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>tel</string>
    </array>
</dict>
```

## Firebase 인증 설정

1. Firebase 콘솔에서 Authentication 섹션 열기
2. '로그인 방법' 탭에서 다음 제공업체 활성화:
   - 이메일/비밀번호
   - Google 로그인 (선택 사항)

## Firebase Firestore 설정

1. Firebase 콘솔에서 Firestore 데이터베이스 생성
2. 테스트 모드로 시작 (나중에 보안 규칙 추가)
3. 기본 컬렉션 생성:
   - users
   - locations
   - messages
   - connections
   - emergencyContacts

## Firebase Cloud Messaging 설정

1. Firebase 콘솔에서 Cloud Messaging 사용 설정
2. Android 및 iOS 푸시 알림 설정 완료
3. 서버 키 생성 및 저장

## Google Maps API 설정

1. [Google Cloud Console](https://console.cloud.google.com)에서 프로젝트 생성
2. Maps SDK for Android 및 iOS 활성화
3. API 키 생성 및 제한 설정
4. API 키를 Android/iOS 설정 파일에 추가

## 개발자 팁

### 디버깅

- Firebase Console의 로그 및 Crashlytics 활용
- Flutter DevTools 사용
- 위치 서비스 디버깅을 위한 모의 위치 사용

### 성능 최적화

- 배터리 소모를 최소화하기 위한 위치 추적 전략 사용
- Firebase 캐싱 전략 구현
- 이미지 및 리소스 최적화

### 보안 고려사항

- API 키 및 민감한 정보는 환경 변수로 관리
- Firebase 보안 규칙 적용
- 사용자 데이터 암호화 고려

이 설정 가이드는 프로젝트 요구사항이 변경됨에 따라 업데이트될 수 있습니다.
