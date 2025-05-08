# iOS 개발 가이드

## 개요

이 문서는 GPS Search 앱의 iOS 버전 개발 및 유지 관리를 위한 가이드라인을 제공합니다. iOS 특화 설정, 문제 해결 방법 및 권장 사항을 담고 있습니다.

## 필수 요구사항

- macOS 컴퓨터
- Xcode 최신 버전 (15.0 이상 권장)
- iOS 개발자 계정 (앱스토어 배포용)
- CocoaPods 설치: `sudo gem install cocoapods`

## iOS 프로젝트 설정

### 1. 초기 설정

```bash
# Flutter 프로젝트 생성 후
cd ios
pod install
cd ..
```

### 2. Xcode에서 프로젝트 열기

```bash
open ios/Runner.xcworkspace
```

> 중요: `.xcodeproj`가 아닌 `.xcworkspace` 파일을 열어야 합니다.

### 3. 앱 식별자 및 팀 설정

1. Xcode에서 Runner 프로젝트 선택
2. 'Signing & Capabilities' 탭 선택
3. 적절한 팀 선택 및 Bundle Identifier 설정

## Info.plist 설정

GPS Search 앱에 필요한 주요 Info.plist 설정:

### 권한 요청 메시지

```xml
<!-- 위치 권한 -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>GPS Search가 위치 공유 기능을 위해 위치 권한이 필요합니다.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>귀가 알림 및 SOS 기능을 위해 백그라운드에서도 위치 정보가 필요합니다.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>백그라운드 위치 추적을 위해 위치 권한이 필요합니다.</string>

<!-- 연락처 권한 (선택적) -->
<key>NSContactsUsageDescription</key>
<string>긴급 연락처 추가를 위해 연락처 접근 권한이 필요합니다.</string>

<!-- 전화 권한 -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tel</string>
</array>

<!-- 카메라 권한 (선택적) -->
<key>NSCameraUsageDescription</key>
<string>프로필 사진 업데이트를 위해 카메라 접근 권한이 필요합니다.</string>
```

### 백그라운드 모드 활성화

```xml
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>remote-notification</string>
    <string>fetch</string>
    <string>processing</string>
</array>
```

## CocoaPods 문제 해결

### 1. Pod 설치 오류

Pod 설치 중 오류가 발생하면 다음 단계를 시도하세요:

```bash
cd ios
pod repo update
pod cache clean --all
pod install --repo-update
cd ..
```

### 2. M1/M2 Mac 관련 문제

Apple Silicon(M1/M2) Mac에서 개발 시 발생할 수 있는 문제:

```bash
# Rosetta로 터미널 열기
# 또는 다음 명령어 사용
arch -x86_64 pod install
```

### 3. 버전 충돌 문제

특정 CocoaPods 버전이 필요한 경우:

```bash
cd ios
pod deintegrate
pod setup
# Podfile에 플랫폼 버전 지정
# platform :ios, '12.0'
pod install
cd ..
```

## 일반적인 iOS 특화 문제 해결

### 1. MissingPluginException

플러그인 등록 문제가 발생할 경우:

```bash
flutter clean
cd ios
pod deintegrate
pod install
cd ..
flutter run
```

Flutter 앱을 완전히 종료하고 재시작하는 것도 도움이 될 수 있습니다.

### 2. iOS 시뮬레이터 문제

시뮬레이터에서 앱이 제대로 작동하지 않는 경우:

1. 시뮬레이터 초기화: iOS Simulator > Device > Erase All Content and Settings
2. 다양한 iOS 버전 및 기기 유형에서 테스트

### 3. 위치 서비스 테스트

iOS 시뮬레이터에서 위치 테스트:

1. 시뮬레이터 메뉴에서 Features > Location 선택
2. 사용자 정의 위치 설정 가능

## 디버깅 및 테스트

### iOS 로그 확인

상세 로그 확인:

```bash
flutter run -d ios -v
```

### Xcode에서 디버깅

1. Xcode에서 프로젝트 열기
2. 실행 버튼 클릭
3. Debug Navigator에서 로그 및 성능 모니터링

## 배포 준비

### 1. 앱 아이콘 설정

1. `ios/Runner/Assets.xcassets/AppIcon.appiconset` 폴더에 다양한 크기의
   아이콘 이미지 추가
2. `Contents.json` 파일이 각 이미지에 대한 올바른 참조를 포함하는지 확인

### 2. LaunchScreen 구성

1. `ios/Runner/Base.lproj/LaunchScreen.storyboard` 파일 수정
2. 앱 로고 및 스플래시 화면 구성

### 3. 배포 인증서 및 프로비저닝 프로필

1. Apple Developer 계정에서 인증서 및 프로비저닝 프로필 생성
2. Xcode의 프로젝트 설정에서 적용

### 4. 앱스토어 배포

1. 앱 버전 및 빌드 번호 업데이트
2. 앱스토어 스크린샷 및 메타데이터 준비
3. `flutter build ios` 명령어로 배포용 빌드 생성
4. Xcode에서 Archive 생성 및 앱스토어 커넥트에 업로드

## iOS 특화 기능 최적화

### 위치 서비스 최적화

iOS에서는 위치 서비스 사용에 더 엄격한 제한이 있습니다:

```dart
// iOS 특화 위치 서비스 요청 코드
if (Platform.isIOS) {
  await Geolocator.requestTemporaryFullAccuracy(purposeKey: "위치공유");
}

// 배터리 최적화를 위한 위치 정확도 조정
final LocationAccuracy accuracy = Platform.isIOS
    ? LocationAccuracy.reduced  // iOS에서는 배터리 절약을 위해
    : LocationAccuracy.high;    // Android에서는 높은 정확도
```

### 푸시 알림 설정

iOS에서 푸시 알림 권한 요청:

```dart
if (Platform.isIOS) {
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
}
```

### 심층 연결(Deep Linking) 설정

Associated Domains 설정:

1. `ios/Runner/Runner.entitlements` 파일에 추가:

   ```xml
   <key>com.apple.developer.associated-domains</key>
   <array>
     <string>applinks:example.com</string>
   </array>
   ```

2. 웹사이트에 Apple App Site Association 파일 추가

## 참고 자료

- [Flutter iOS 통합 가이드](https://flutter.dev/docs/development/platform-integration/ios)
- [CocoaPods 공식 문서](https://cocoapods.org)
- [Apple Developer 문서](https://developer.apple.com/documentation/)
- [크로스 플랫폼 호환성 가이드](./cross_platform_compatibility.md)

---

문의사항: example@example.com
