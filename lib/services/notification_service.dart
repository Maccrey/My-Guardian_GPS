import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// 알림 서비스
/// 로컬 알림을 관리하고 표시하는 기능을 제공합니다.
class NotificationService extends GetxController {
  // 싱글톤 인스턴스
  static NotificationService? _instance;

  static Future<NotificationService> getInstance() async {
    if (_instance == null) {
      _instance = NotificationService._();
      await _instance!._init();
    }
    return _instance!;
  }

  // 알림 플러그인
  // final FlutterLocalNotificationsPlugin _notificationsPlugin =
  //     FlutterLocalNotificationsPlugin();

  // 알림 활성화 상태
  final RxBool isNotificationEnabled = true.obs;

  // 생성자
  NotificationService._();

  // 초기화
  Future<void> _init() async {
    try {
      // SharedPreferences에서 알림 설정 로드
      final prefs = await SharedPreferences.getInstance();
      isNotificationEnabled.value =
          prefs.getBool('notification_enabled') ?? true;

      // 알림 권한 요청
      await _requestNotificationPermissions();

      debugPrint('✅ NotificationService 초기화 완료 (간소화된 버전)');
    } catch (e) {
      debugPrint('❌ NotificationService 초기화 오류: $e');
    }
  }

  /// 알림 권한 요청
  Future<bool> _requestNotificationPermissions() async {
    // 권한 요청 생략
    return true;
  }

  /// 로컬 알림 초기화
  Future<void> setupLocalNotifications() async {
    debugPrint('✅ 로컬 알림 초기화 완료 (임시로 비활성화됨)');
  }

  /// 알림 표시
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'home_arrival_channel',
  }) async {
    if (!isNotificationEnabled.value) {
      debugPrint('⚠️ 알림이 비활성화되어 있습니다.');
      return;
    }

    debugPrint('📱 알림 표시 (임시로 비활성화됨): $title - $body');
  }

  /// 메시지 알림 표시
  Future<void> showMessageNotification({
    required int id,
    required String senderName,
    required String message,
    required String senderId,
  }) async {
    debugPrint('📱 메시지 알림 표시 (임시로 비활성화됨): $senderName - $message');
  }

  /// 위치 공유 알림 표시
  Future<void> showLocationSharingNotification({
    required int id,
    required String title,
    required String body,
    required String userId,
  }) async {
    debugPrint('📱 위치 공유 알림 표시 (임시로 비활성화됨): $title - $body');
  }

  /// 알림 설정 변경
  Future<void> setNotificationEnabled(bool enabled) async {
    try {
      isNotificationEnabled.value = enabled;

      // 설정 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_enabled', enabled);

      debugPrint('✅ 알림 설정 변경: $enabled');
    } catch (e) {
      debugPrint('❌ 알림 설정 변경 오류: $e');
    }
  }

  /// 모든 알림 취소
  Future<void> cancelAllNotifications() async {
    try {
      // await _notificationsPlugin.cancelAll();
      debugPrint('✅ 모든 알림 취소 완료');
    } catch (e) {
      debugPrint('❌ 알림 취소 오류: $e');
    }
  }
}
