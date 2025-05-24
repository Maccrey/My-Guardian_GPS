import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

/// 앱 전체의 알림을 관리하는 서비스 (임시로 간소화됨)
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
    debugPrint('✅ NotificationService 초기화 완료 (간소화된 버전)');
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
      debugPrint('✅ 알림 ${enabled ? "활성화" : "비활성화"} 설정 완료');
    } catch (e) {
      debugPrint('⚠️ 알림 설정 변경 오류: $e');
    }
  }

  // 앱 알림 보내기 (로컬 알림) - 임시로 로깅만 함
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    // 알림이 비활성화된 경우 무시
    if (!isNotificationEnabled.value) {
      debugPrint('⚠️ 알림이 비활성화되어 있어 표시되지 않습니다.');
      return;
    }

    debugPrint('✅ [임시] 로컬 알림: $title - $body');
  }

  // 메시지 알림 보내기 - 임시로 로깅만 함
  Future<void> showMessageNotification({
    required String senderName,
    required String messageContent,
    required String senderId,
    int id = 1,
  }) async {
    // 알림이 비활성화된 경우 무시
    if (!isNotificationEnabled.value) {
      debugPrint('⚠️ 알림이 비활성화되어 있어 메시지 알림이 표시되지 않습니다.');
      return;
    }

    debugPrint('✅ [임시] 메시지 알림: $senderName - $messageContent');
  }

  // 위치 공유 알림 표시 - 임시로 로깅만 함
  Future<void> showLocationSharingNotification({
    required String senderName,
    required String message,
    required String senderId,
    required bool isStarting,
    String? locationId,
    int id = 2,
  }) async {
    // 알림이 비활성화된 경우 무시
    if (!isNotificationEnabled.value) {
      debugPrint('⚠️ 알림이 비활성화되어 있어 위치 공유 알림이 표시되지 않습니다.');
      return;
    }

    debugPrint('✅ [임시] 위치 공유 알림: $senderName - $message');
  }
}
