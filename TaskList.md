# 귀가 알림 앱 개발 Task List (MSA + TDD)

## Phase 1: 프로젝트 구조 및 환경 설정

- [ ] 1-1. MSA 스타일 디렉토리 구조 설계 및 생성
  - features: UI 및 상태관리 (예: home_setting, tracking)
  - services: 위치, 알림, 백그라운드 등 핵심 로직
  - core: 공통 유틸리티, 권한 처리 등
  - models: 데이터 모델 정의
- [ ] 1-2. 주요 의존성 패키지 점검 및 추가
  - 위치: geolocator, geocoding
  - 지도: google_maps_flutter, flutter_polyline_points
  - 알림: flutter_local_notifications (필요시 pubspec.yaml에 추가)
  - 백그라운드: flutter_background_service, flutter_background_service_android, flutter_background_service_ios
  - 저장소: shared_preferences
  - 권한: permission_handler
  - 상태관리: get
- [ ] 1-3. 환경 변수 및 리소스(assets) 설정

## Phase 2: 핵심 기능 개발 (TDD 기반)

- [ ] 2-1. 집 위치 설정 및 저장 기능
  - [ ] Test: 집 위치 저장/로드 유닛 테스트
  - [ ] Implement: UI에서 집 위치 설정, shared_preferences 저장
- [ ] 2-2. 거리 계산 유틸리티
  - [ ] Test: 두 좌표 거리 계산 유닛 테스트
  - [ ] Implement: 거리 계산 함수(core/utils)
- [ ] 2-3. 위치 기반 조건 확인 로직
  - [ ] Test: 30m 이내 여부 판단 유닛 테스트
  - [ ] Implement: location_service에서 거리 계산 활용
- [ ] 2-4. 포그라운드 알림 기능
  - [ ] Test: 조건 충족 시 알림 전송 Mock 테스트
  - [ ] Implement: notification_service로 로컬 푸시 메시지 전송

## Phase 3: 백그라운드 실행 및 권한 처리

- [ ] 3-1. Android
  - [ ] 3-1-1. AndroidManifest.xml 권한 추가
  - [ ] 3-1-2. 포그라운드 서비스 구현 및 테스트
  - [ ] 3-1-3. 위치/알림 권한 요청 로직 구현 및 테스트
- [ ] 3-2. iOS
  - [ ] 3-2-1. Info.plist 권한/백그라운드 설정
  - [ ] 3-2-2. '항상 허용' 권한 요청 UI/로직 및 테스트
  - [ ] 3-2-3. 백그라운드 위치 업데이트 활성화 및 테스트

## Phase 4: 통합 및 최종 테스트

- [ ] 4-1. 시작/중지 버튼 UI 및 서비스 연동
- [ ] 4-2. 실제 기기 통합 테스트(알림, 배터리 등)
- [ ] 4-3. 코드 리팩토링 및 주석/문서 정리

---

## 참고

- 각 서비스/유틸리티/모델은 독립적으로 테스트 및 재사용 가능하게 설계
- 모든 함수/클래스에 한글 주석 필수
- 불필요한 파일/코드는 구현 중 정리
- 구현 완료 시 README.md에 요약 정리
