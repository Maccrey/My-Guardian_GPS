# 크로스 플랫폼 호환성 가이드

## 개요

GPS Search 앱은 Flutter를 사용하여 개발되었으며, iOS와 Android 모두에서 원활하게 작동하도록 설계되었습니다. 이 문서는 두 플랫폼 모두에서 일관된 사용자 경험을 제공하기 위한 가이드라인을 제공합니다.

## 일반 지침

1. **플랫폼 특화 코드 처리**

   ```dart
   import 'dart:io' show Platform;

   if (Platform.isAndroid) {
     // 안드로이드 특화 로직
   } else if (Platform.isIOS) {
     // iOS 특화 로직
   }
   ```

2. **UI 요소 적응**

   - Material 디자인(Android)과 Cupertino(iOS) 스타일을 적절히 혼합
   - 플랫폼 별 네이티브 위젯 사용 고려

3. **플러그인 호환성 확인**
   - 사용하는 모든 Flutter 플러그인이 iOS와 Android 모두 지원하는지 확인
   - 일부 플러그인은 플랫폼별 설정이 필요함

## 네이티브 플러그인 통합 시 고려사항

### 새 플러그인 추가 절차

1. pubspec.yaml에 플러그인 추가
2. 플랫폼별 설정 확인
   - iOS: 필요한 경우 Info.plist 업데이트
   - Android: AndroidManifest.xml 및 build.gradle 업데이트
3. 완전한 앱 재빌드
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install && cd ..  # iOS용
   cd android && ./gradlew clean && cd ..  # Android용
   flutter run
   ```

### 공통 오류 방지

1. **MissingPluginException**

   - 항상 완전한 앱 재빌드
   - iOS와 Android 모두에서 테스트
   - 플러그인 메서드 호출 시 try-catch 사용

2. **플랫폼 별 권한 처리**
   - iOS: Info.plist에 필요한 권한 및 설명 추가
   - Android: AndroidManifest.xml에 필요한 권한 추가

## iOS 특화 설정

### Info.plist 권한 설정

```xml
<!-- 위치 권한 -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>위치 공유 기능을 위해 위치 권한이 필요합니다.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>백그라운드 위치 추적을 위해 항상 위치 권한이 필요합니다.</string>

<!-- 연락처 권한 -->
<key>NSContactsUsageDescription</key>
<string>긴급 연락처 기능을 위해 연락처 접근 권한이 필요합니다.</string>

<!-- 카메라 권한 -->
<key>NSCameraUsageDescription</key>
<string>프로필 사진 업데이트를 위해 카메라 접근 권한이 필요합니다.</string>
```

### CocoaPods 관련 이슈 해결

1. **Pod 설치 오류**

   ```bash
   cd ios
   pod repo update
   pod install --repo-update
   cd ..
   ```

2. **최소 iOS 버전 확인**
   - iOS/Runner.xcodeproj/project.pbxproj에서 IPHONEOS_DEPLOYMENT_TARGET 확인
   - 최소 iOS 버전 11.0 이상 권장

## Android 특화 설정

### Gradle 및 SDK 설정

1. **minSdkVersion 확인**

   - 앱의 기능을 지원하기 위해 최소 SDK 버전 16 이상 설정
   - 가능하면 SDK 버전 21 이상 권장 (Android 5.0+)

2. **Gradle 버전 관리**
   - android/gradle/wrapper/gradle-wrapper.properties 확인
   - android/build.gradle의 buildscript 섹션 확인

### 플랫폼 특화 권한 요청

```dart
import 'package:permission_handler/permission_handler.dart';

Future<void> requestLocationPermission() async {
  if (Platform.isAndroid) {
    // Android 10+ (API 29+)에서는 백그라운드 위치 권한 별도 요청
    final androidVersion = await DeviceInfoPlugin().androidInfo;
    if (androidVersion.version.sdkInt >= 29) {
      await Permission.locationAlways.request();
    }
  }

  // 일반 위치 권한
  await Permission.location.request();
}
```

## 테스트 절차

1. **테스트 기기 다양화**

   - 최소 2개 이상의 iOS 기기/에뮬레이터 (iPhone/iPad)
   - 최소 3개 이상의 Android 기기/에뮬레이터 (다른 화면 크기, OS 버전)

2. **통합 테스트 시나리오**

   ```
   1. 앱 설치 및 첫 실행
   2. 권한 요청 및 확인
   3. 로그인 및 회원가입
   4. 주요 기능 테스트
   5. 백그라운드/포그라운드 전환
   6. 앱 종료 및 재시작
   7. 오프라인 모드 테스트
   ```

3. **플랫폼별 특화 테스트**
   - iOS: 백그라운드 앱 갱신, Notification Center
   - Android: 백그라운드 서비스, 도즈 모드, 배터리 최적화 예외

## 문제해결 가이드

### 공통 문제

1. **플러그인 오류**

   - 완전한 앱 재빌드
   - 플러그인 버전 확인 및 업데이트

2. **UI 렌더링 불일치**
   - 적응형 레이아웃 사용
   - MediaQuery를 활용한 화면 크기 대응

### iOS 특화 문제

1. **iOS 시뮬레이터 문제**

   - 시뮬레이터 리셋: iOS 시뮬레이터 메뉴의 "Reset Content and Settings"
   - 최신 Xcode 및 iOS 시뮬레이터 업데이트

2. **iOS CocoaPods 오류**
   ```bash
   cd ios
   pod deintegrate
   pod setup
   pod install
   cd ..
   ```

### Android 특화 문제

1. **Gradle 빌드 오류**

   ```bash
   cd android
   ./gradlew clean
   ./gradlew --refresh-dependencies
   cd ..
   ```

2. **Android 에뮬레이터 문제**
   - AVD 매니저에서 에뮬레이터 재생성
   - "Cold Boot" 옵션으로 에뮬레이터 시작

## 배포 전 체크리스트

1. **iOS 배포 체크리스트**

   - AppStore Connect 계정 설정
   - 앱 아이콘 및 스플래시 스크린 확인
   - 필요한 모든 Info.plist 항목 확인
   - TestFlight 테스트

2. **Android 배포 체크리스트**
   - Google Play Console 계정 설정
   - 앱 서명 키 생성 및 관리
   - 앱 아이콘 및 필요한 리소스 확인
   - 내부 테스트 트랙 배포 및 테스트

---

이 문서는 GPS Search 앱의 크로스 플랫폼 호환성을 유지하기 위한 가이드라인입니다. 모든 개발자는 이 지침을 따라 iOS와 Android 모두에서 일관된 사용자 경험을 제공해야 합니다.

개발 관련 문의: example@example.com
