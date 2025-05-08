# GPS Search - 코드 컨벤션

## 개요

이 문서는 GPS Search 앱 개발에 참여하는 모든 개발자가 일관된 코드 스타일을 유지하기 위한 가이드라인을 제공합니다.

## 파일 구조

```
lib/
├── main.dart
├── models/            # 데이터 모델 클래스
├── views/             # UI 화면 (GetX Controller 사용)
├── controllers/       # GetX 컨트롤러 (비즈니스 로직)
├── services/          # 서비스 계층 (API, Firebase 등)
├── utils/             # 유틸리티 함수 및 클래스
├── widgets/           # 재사용 가능한 위젯
└── routes/            # 라우팅 관련 설정
```

## 네이밍 컨벤션

### 클래스 및 파일명

- 클래스: `PascalCase` (예: `UserModel`, `HomeView`)
- 파일: `snake_case` (예: `user_model.dart`, `home_view.dart`)

### 변수 및 함수명

- 변수: `camelCase` (예: `userName`, `isLoading`)
- 함수: `camelCase` (예: `getUserData()`, `updateLocation()`)
- 비공개 멤버: `_` 접두사 (예: `_privateVariable`, `_privateMethod()`)

### GetX 관련 네이밍

- 컨트롤러: `[Feature]Controller` (예: `LocationController`, `AuthController`)
- 서비스: `[Feature]Service` (예: `LocationService`, `AuthService`)
- 바인딩: `[Feature]Binding` (예: `HomeBinding`, `ProfileBinding`)

## 코드 포맷팅

- 들여쓰기: 2 공백
- 줄 길이: 최대 80자 (예외 경우에만 초과)
- 괄호: K&R 스타일 사용

## Flutter/Dart 특화 규칙

- `const` 생성자 최대한 활용
- 위젯 트리에서 명확한 구조화를 위한 적절한 들여쓰기 사용
- 위젯 파라미터가 많은 경우 각 파라미터를 새 줄에 배치

## GetX 사용 규칙

- 상태 관리: `.obs` 변수와 `Obx()` 위젯 사용
- 라우팅: Get.to(), Get.toNamed() 등 사용
- 의존성 주입: Get.put(), Get.find() 사용
- UI와 비즈니스 로직 분리: Controller에 비즈니스 로직 배치

## 비동기 처리

- Future/async-await 사용 시 적절한 에러 처리 포함
- 상태 표시 (로딩, 에러 등)를 명확히 처리

## 주석 가이드라인

- 클래스와 공개 메서드에 문서 주석 (`///`) 추가
- 복잡한 로직이나 비즈니스 규칙에 설명 주석 추가
- 주석은 한국어로 작성

## 위치 서비스 관련 규칙

- 위치 데이터 처리 시 항상 권한 확인
- 백그라운드 위치 추적 시 배터리 최적화 고려
- 위치 공유 상태를 명확히 표시하는 UI 요소 포함

## Firebase 관련 규칙

- Firestore 컬렉션 및 문서 ID 규칙 준수
- 인증 상태 변경 시 적절한 에러 처리
- 실시간 데이터 동기화 시 적절한 상태 관리

이 가이드라인은 프로젝트가 진행됨에 따라 업데이트될 수 있습니다.
