import 'package:get/get.dart';
import '../services/location_sharing_service.dart';
import '../models/shared_location_model.dart'; // SharedLocation 모델
import 'package:flutter/material.dart';

class LocationSharingController extends GetxController {
  // 싱글톤 인스턴스
  static LocationSharingController? _instance;

  // 기본 생성자 추가
  LocationSharingController()
      : _locationService = Get.find<LocationSharingService>() {
    debugPrint('📱 LocationSharingController 기본 생성자 호출됨');
  }

  // 싱글톤 접근 메소드
  static Future<LocationSharingController> getInstance() async {
    try {
      if (_instance == null) {
        // LocationSharingService 먼저 초기화
        final locationService = await LocationSharingService.getInstance();

        _instance = LocationSharingController._internal(locationService);

        // 이미 GetX에 등록되어 있는지 확인
        if (!Get.isRegistered<LocationSharingController>()) {
          Get.put(_instance!, permanent: true);
          debugPrint('✅ LocationSharingController GetX에 등록됨');
        }
      }
      return _instance!;
    } catch (e) {
      debugPrint('❌ LocationSharingController 싱글톤 인스턴스 생성 오류: $e');
      // 오류 발생 시에도 인스턴스 생성하여 반환 (LocationSharingService로부터 안전하게 가져오기)
      if (_instance == null) {
        try {
          final locationService = await LocationSharingService.getInstance();
          _instance = LocationSharingController._internal(locationService);

          if (!Get.isRegistered<LocationSharingController>()) {
            Get.put(_instance!, permanent: true);
          }
        } catch (innerError) {
          debugPrint('❌ LocationSharingController 복구 시도 실패: $innerError');
          // 아무것도 등록되지 않은 경우를 대비한 코드
          if (!Get.isRegistered<LocationSharingService>()) {
            debugPrint('⚠️ LocationSharingService가 등록되지 않음, 빈 인스턴스 생성 시도');
            final emptyService = LocationSharingService();
            Get.put(emptyService, permanent: true);
            _instance = LocationSharingController._internal(emptyService);
            if (!Get.isRegistered<LocationSharingController>()) {
              Get.put(_instance!, permanent: true);
            }
          }
        }
      }
      return _instance!;
    }
  }

  // 내부 생성자
  LocationSharingController._internal(this._locationService);

  final LocationSharingService _locationService;

  // 위치 공유 상태
  RxBool get isSharingLocation => _locationService.isSharingLocation;

  // 위치 공유 중인 사용자 ID 목록
  RxList<String> get sharingToUserIds => _locationService.sharingToUserIds;

  // 위치 공유 중인 사용자 수
  RxInt get sharingCount => _locationService.sharingToUserIds.length.obs;

  // 활성 공유 정보 가져오기
  Map<String, SharedLocation> get activeSharing =>
      _locationService.getActiveSharing();

  // 위치 공유 시작
  Future<bool> startSharing(String contactId) async {
    return await _locationService.startLocationSharing(contactId);
  }

  // 위치 공유 중지
  Future<bool> stopSharing(String contactId) async {
    return await _locationService.stopLocationSharing(contactId);
  }

  // 모든 위치 공유 중지
  Future<void> stopAllSharing() async {
    await _locationService.stopAllLocationSharing();
  }

  // 위치 공유 상태 확인
  bool isShareLocationActive(String contactId) {
    return _locationService.isShareLocationActive(contactId);
  }

  // 특정 사용자의 실시간 위치 구독
  Stream<SharedLocation> subscribeToUserLocation(String userId) {
    return _locationService.subscribeToUserLocation(userId);
  }

  // 위치 업데이트 간격 설정
  void setUpdateInterval(int seconds) {
    _locationService.setUpdateInterval(seconds);
  }

  // 수신자 이름 가져오기 (긴급 연락처 또는 사용자)
  Future<String> getReceiverName(String receiverId) async {
    return await _locationService.getReceiverName(receiverId);
  }
}
