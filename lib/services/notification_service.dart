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

  // 알림 플러그인 (임시로 주석 처리)
  // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  //     FlutterLocalNotificationsPlugin();

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
    // 알림 초기화 (임시로 주석 처리)
    // await _initNotifications();

    // 설정 불러오기
    await loadSettings();
    debugPrint('✅ NotificationService 초기화 완료 (간소화된 버전)');
  }

  // 알림 초기화 (임시로 주석 처리)
  /*
  Future<void> _initNotifications() async {
    // 안드로이드 초기화 설정
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // iOS 초기화 설정
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: onDidReceiveLocalNotification,
    );

    // 초기화 설정 통합
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // 알림 플러그인 초기화
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );

    // 안드로이드용 알림 채널 생성
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        '중요 알림',
        description: '긴급 상황 및 중요 알림을 위한 채널',
        importance: Importance.high,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    debugPrint('✅ 알림 초기화 완료');
  }

  // iOS 알림 수신 핸들러 (iOS 10 미만용)
  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    debugPrint('알림 수신 (iOS 10 미만): $title - $body');
  }

  // 알림 응답 핸들러
  void onDidReceiveNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      debugPrint('알림 페이로드: ${response.payload}');
      // 페이로드에 따른 네비게이션 또는 작업 수행 가능
    }
  }
  */

  // 권한 요청
  Future<void> requestNotificationsPermission() async {
    // 임시로 로깅만 수행
    debugPrint('✅ [임시] 알림 권한 요청 (실제로는 요청하지 않음)');

    /* 원래 코드 (임시로 주석 처리)
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestPermission();
    }
    */
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
