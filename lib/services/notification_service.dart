import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전체의 알림을 관리하는 서비스
class NotificationService extends GetxController {
  // 알림 활성화 상태
  final RxBool isNotificationEnabled = true.obs;

  // SharedPreferences 키
  static const String _notificationEnabledKey = 'isNotificationEnabled';

  // Singleton 패턴 적용
  static NotificationService? _instance;

  static Future<NotificationService> getInstance() async {
    if (_instance == null) {
      _instance = NotificationService();
      await _instance!._init();
    }
    return _instance!;
  }

  // 초기화 함수
  Future<void> _init() async {
    // 설정 불러오기
    await loadSettings();
    debugPrint('✅ NotificationService 초기화 완료');
  }

  // 설정 불러오기
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isNotificationEnabled.value =
          prefs.getBool(_notificationEnabledKey) ?? true;

      debugPrint(
          '✅ 알림 설정 불러오기 완료: ${isNotificationEnabled.value ? "활성화" : "비활성화"}');
    } catch (e) {
      debugPrint('⚠️ 알림 설정 불러오기 오류: $e');
    }
  }

  // 알림 활성화/비활성화 설정
  Future<void> setNotificationEnabled(bool enabled) async {
    isNotificationEnabled.value = enabled;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationEnabledKey, enabled);

      // 알림 상태에 따른 처리
      if (enabled) {
        await _enableNotifications();
      } else {
        await _disableNotifications();
      }

      debugPrint('✅ 알림 ${enabled ? "활성화" : "비활성화"} 설정 완료');
    } catch (e) {
      debugPrint('⚠️ 알림 설정 변경 오류: $e');
    }
  }

  // 알림 활성화 처리
  Future<void> _enableNotifications() async {
    // TODO: 실제 알림 서비스 활성화 코드 구현
    // 예: Firebase Cloud Messaging 등록, 권한 요청 등
    debugPrint('✅ 알림 서비스 활성화됨');
  }

  // 알림 비활성화 처리
  Future<void> _disableNotifications() async {
    // TODO: 실제 알림 서비스 비활성화 코드 구현
    // 예: Firebase Cloud Messaging 토큰 삭제 등
    debugPrint('✅ 알림 서비스 비활성화됨');
  }

  // 앱 알림 보내기 (로컬 알림)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // 알림이 비활성화된 경우 무시
    if (!isNotificationEnabled.value) {
      debugPrint('⚠️ 알림이 비활성화되어 있어 표시되지 않습니다.');
      return;
    }

    // TODO: 실제 로컬 알림 표시 코드 구현
    // 예: flutter_local_notifications 플러그인 사용
    debugPrint('✅ 로컬 알림 표시: $title - $body');
  }
}
