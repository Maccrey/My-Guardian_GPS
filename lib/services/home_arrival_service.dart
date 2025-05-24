import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
// 임시로 주석 처리 (빌드 오류 방지)
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:watch_over/services/location_service.dart';
import 'package:watch_over/services/auth_service.dart';
import 'package:watch_over/services/message_service.dart';
import 'package:watch_over/services/emergency_contact_service.dart';

/// 임시로 간소화된 HomeArrivalService
class HomeArrivalService extends GetxController {
  // 싱글톤 패턴
  static HomeArrivalService? _instance;

  static Future<HomeArrivalService> getInstance() async {
    if (_instance == null) {
      _instance = HomeArrivalService();
      await _instance!._init();
    }
    return _instance!;
  }

  // 서비스 상태
  final RxBool isEnabled = false.obs;
  final RxString trackingStatus = '추적 비활성화'.obs;
  final RxBool isArrivingHome = false.obs;
  final RxBool isTrackingEnabled = false.obs;
  final RxList<String> messageRecipientIds = <String>[].obs;

  // 임시 필드 (빌드 오류 방지)
  final RxString arrivalMessage = '집에 안전하게 도착했습니다.'.obs;

  // 상수
  static const String PREF_TRACKING_ENABLED = 'home_arrival_tracking_enabled';
  static const String PREF_RECIPIENT_IDS = 'home_arrival_recipient_ids';

  // 서비스 의존성
  late LocationService _locationService;
  late MessageService _messageService;
  late AuthService _authService;
  late EmergencyContactService _emergencyContactService;

  // 초기화
  Future<void> _init() async {
    try {
      // 서비스 인스턴스 가져오기
      _locationService = Get.find<LocationService>();
      _authService = Get.find<AuthService>();
      _messageService = Get.find<MessageService>();
      _emergencyContactService = Get.find<EmergencyContactService>();

      // 저장된 설정 로드
      await _loadSettings();

      debugPrint('✅ HomeArrivalService 초기화 성공 (간소화된 버전)');
    } catch (e) {
      debugPrint('❌ HomeArrivalService 초기화 오류: $e');
    }
  }

  // 설정 로드
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 귀가 추적 활성화 여부
      isTrackingEnabled.value = prefs.getBool(PREF_TRACKING_ENABLED) ?? false;

      // 메시지 수신자 ID 목록
      final recipientIdsJson = prefs.getStringList(PREF_RECIPIENT_IDS) ?? [];
      messageRecipientIds.value = recipientIdsJson;

      debugPrint('✅ HomeArrivalService 설정 로드 완료');
    } catch (e) {
      debugPrint('❌ HomeArrivalService 설정 로드 오류: $e');
    }
  }

  // 설정 저장
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 귀가 추적 활성화 여부
      await prefs.setBool(PREF_TRACKING_ENABLED, isTrackingEnabled.value);

      // 수신자 ID 목록
      await prefs.setStringList(PREF_RECIPIENT_IDS, messageRecipientIds);

      debugPrint('✅ HomeArrivalService 설정 저장 완료');
    } catch (e) {
      debugPrint('❌ HomeArrivalService 설정 저장 오류: $e');
    }
  }

  // 앱 재시작 시 도착 알림 확인 및 처리 (임시로 간소화)
  Future<void> checkPendingArrivalNotification() async {
    debugPrint('✅ [임시] 대기 중인 귀가 알림 확인 (간소화됨)');
  }

  // 임시 메서드 (빌드 오류 방지)
  Future<void> refreshTrackingStatus() async {
    debugPrint('✅ [임시] 추적 상태 업데이트 (간소화됨)');
  }

  // 임시 메서드 (빌드 오류 방지)
  Future<void> stopTracking() async {
    isTrackingEnabled.value = false;
    isArrivingHome.value = false;
    trackingStatus.value = '추적 비활성화';
    debugPrint('✅ [임시] 추적 중지 (간소화됨)');
  }

  // 임시 메서드 (빌드 오류 방지)
  Future<bool> startTracking() async {
    isTrackingEnabled.value = true;
    isArrivingHome.value = true;
    trackingStatus.value = '집 근처 감지 중...';
    debugPrint('✅ [임시] 추적 시작 (간소화됨)');
    return true;
  }

  // 서비스 종료 시 정리
  @override
  void onClose() {
    super.onClose();
  }
}
