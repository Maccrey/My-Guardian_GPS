# GPS Search - 아키텍처 설계

## 개요

GPS Search는 GetX 패턴을 기반으로 한 클린 아키텍처를 따릅니다. 이 문서는 앱의 전반적인 아키텍처와 각 계층의 역할에 대해 설명합니다.

## 아키텍처 계층

### 1. 프레젠테이션 계층 (Presentation Layer)

UI 관련 코드를 포함하며, 사용자와의 상호작용을 담당합니다.

**구성요소:**

- `views/`: 화면을 나타내는 위젯
- `widgets/`: 재사용 가능한 UI 컴포넌트
- `routes/`: 앱 내 라우팅 설정

### 2. 비즈니스 로직 계층 (Business Logic Layer)

앱의 핵심 기능과 상태 관리를 담당합니다.

**구성요소:**

- `controllers/`: GetX 컨트롤러
- `bindings/`: GetX 의존성 바인딩

### 3. 데이터 계층 (Data Layer)

데이터 액세스 및 모델을 담당합니다.

**구성요소:**

- `models/`: 데이터 모델 클래스
- `services/`: 데이터 액세스 서비스
- `repositories/`: 데이터 소스와 비즈니스 로직 간의 중간 계층

### 4. 유틸리티 계층 (Utility Layer)

앱 전반에 걸쳐 사용되는 유틸리티 기능을 제공합니다.

**구성요소:**

- `utils/`: 헬퍼 함수 및 클래스
- `constants/`: 상수 및 설정값

## 데이터 흐름

1. UI 이벤트 발생 (예: 버튼 클릭)
2. GetX 컨트롤러에서 이벤트 처리
3. 필요시 서비스 계층을 통해 데이터 액세스
4. 상태 업데이트 및 반응형 UI 갱신

## 핵심 모듈

### 인증 모듈

- `AuthController`: 인증 상태 및 로직 관리
- `AuthService`: Firebase Authentication 연동
- `UserModel`: 사용자 데이터 모델

### 위치 모듈

- `LocationController`: 위치 추적 및 공유 로직
- `LocationService`: 위치 정보 수집 및 Firebase 저장
- `LocationModel`: 위치 데이터 모델

### 메시지 모듈

- `MessageController`: 메시지 관리 로직
- `MessageService`: Firebase Cloud Messaging 연동
- `MessageModel`: 메시지 데이터 모델

### SOS 모듈

- `SOSController`: SOS 기능 로직
- `EmergencyService`: 긴급 알림 및 통화 기능
- `EmergencyContactModel`: 긴급 연락처 모델

## 의존성 관리

GetX의 의존성 주입 시스템을 사용하여 각 컴포넌트 간의 결합도를 낮춥니다.

```dart
// 예시: 의존성 주입 방식
void main() {
  // 서비스 등록
  Get.put(AuthService());
  Get.put(LocationService());

  runApp(MyApp());
}

// 컨트롤러에서 서비스 사용
class LocationController extends GetxController {
  final locationService = Get.find<LocationService>();

  void startLocationTracking() {
    locationService.startTracking();
  }
}
```

## 상태 관리

GetX의 반응형 상태 관리를 사용하여 앱의 상태를 효율적으로 관리합니다.

```dart
// 예시: 반응형 상태 관리
class LocationController extends GetxController {
  final RxBool isTracking = false.obs;
  final Rx<LocationModel?> currentLocation = Rx<LocationModel?>(null);

  void toggleTracking() {
    isTracking.value = !isTracking.value;
    // 추가 로직...
  }
}

// 뷰에서 사용
Obx(() => Text(controller.isTracking.value ? "추적 중" : "중지됨"))
```

## Firebase 구조

### Firestore 컬렉션 구조

- `users`: 사용자 정보
- `locations`: 위치 데이터
- `messages`: 위치 공유 요청 메시지
- `connections`: 사용자 간 연결 정보
- `emergencyContacts`: 긴급 연락처 설정

### Authentication

사용자 인증에는 Firebase Authentication을 사용합니다. 이메일/비밀번호 방식과 함께 소셜 로그인도 구현할 수 있습니다.

### Cloud Messaging

푸시 알림에는 Firebase Cloud Messaging을 사용합니다. 백그라운드 알림도 처리할 수 있도록 구성합니다.

## 백그라운드 로직

Flutter의 백그라운드 서비스와 Firebase를 조합하여 다음 기능을 구현합니다:

1. 백그라운드 위치 추적
2. 백그라운드 푸시 알림 수신
3. SOS 기능의 백그라운드 처리

## 확장성 고려사항

1. 모듈화: 각 기능을 독립적인 모듈로 구성하여 유지보수 및 확장을 용이하게 함
2. 테스트 용이성: 의존성 주입을 통해 단위 테스트가 가능한 구조 유지
3. 성능 최적화: 위치 추적시 배터리 소모 최소화 전략 적용

이 아키텍처는 앱의 성장에 따라 지속적으로 개선되고 발전할 수 있습니다.
