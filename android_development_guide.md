# 안드로이드 개발 가이드

## 플러그인 관련 이슈 해결 방법

### MissingPluginException 해결하기

안드로이드에서 `MissingPluginException` 오류가 발생할 경우 다음 단계를 따라 해결하세요:

1. **앱 완전 재빌드**

   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **안드로이드 특화 문제 해결**

   - Gradle 캐시 삭제:
     ```bash
     cd android
     ./gradlew clean
     cd ..
     ```
   - Android 플러그인 재등록:
     ```bash
     flutter pub cache repair
     flutter pub get
     ```

3. **프로젝트 구조 확인**

   - `android/app/src/main/java/YOUR_PACKAGE_PATH/MainActivity.java` 파일에서 플러그인이 올바르게 등록되어 있는지 확인
   - `android/settings.gradle`과 `android/app/build.gradle` 파일이 최신 상태인지 확인

4. **minSdkVersion 확인**

   - `android/app/build.gradle` 파일에서 minSdkVersion이 최소 16 이상으로 설정되어 있는지 확인

5. **디바이스 재시작**
   - 실행 중인 에뮬레이터나 디바이스를 완전히 종료하고 다시 시작
   - 앱을 완전히 제거하고 다시 설치

## 안드로이드 배포 준비

1. **서명 키 생성**

   ```bash
   keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
   ```

2. **key.properties 파일 생성**
   `android/key.properties` 파일을 생성하고 다음 내용을 추가:

   ```
   storePassword=<비밀번호>
   keyPassword=<비밀번호>
   keyAlias=key
   storeFile=<키 저장 경로>
   ```

3. **앱 아이콘 업데이트**
   `android/app/src/main/res/` 경로의 mipmap 폴더에 다양한 크기의 앱 아이콘 추가

4. **앱 이름 변경**
   `android/app/src/main/AndroidManifest.xml` 파일에서 `android:label` 값 변경

5. **패키지 이름 변경**
   `android/app/build.gradle` 파일의 `applicationId` 및 관련 Java 패키지 경로 변경

## 권한 관리

GPS Search 앱에 필요한 안드로이드 권한:

1. **위치 정보 접근 권한**
   `AndroidManifest.xml`에 추가:

   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" /> <!-- 백그라운드 위치 추적용 -->
   ```

2. **인터넷 접속 권한**

   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   ```

3. **전화 걸기 권한 (SOS 기능용)**

   ```xml
   <uses-permission android:name="android.permission.CALL_PHONE" />
   ```

4. **푸시 알림 권한**

   ```xml
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
   <uses-permission android:name="android.permission.VIBRATE" />
   ```

5. **연락처 접근 권한 (선택적)**
   ```xml
   <uses-permission android:name="android.permission.READ_CONTACTS" />
   ```

## 성능 최적화 팁

1. **이미지 최적화**: WebP 형식 사용
2. **앱 크기 축소**: ProGuard 규칙 적용
3. **배터리 사용량 최적화**: 백그라운드 서비스 제한적 사용
4. **네트워크 호출 최적화**: 캐싱 전략 구현

## 문제 해결

추가적인 문제가 발생할 경우 다음 명령어로 상세 로그 확인:

```bash
flutter run -v
```

연락처: example@example.com
