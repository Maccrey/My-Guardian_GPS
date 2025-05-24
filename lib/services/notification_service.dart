import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

/// 앱 전체의 알림을 관리하는 서비스
class NotificationService extends GetxController {
  // 로컬 알림 플러그인 인스턴스
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 알림 활성화 상태
  final RxBool isNotificationEnabled = true.obs;

  // SharedPreferences 키
  static const String _notificationEnabledKey = 'isNotificationEnabled';

  // 알림 채널 ID
  static const String _channelId = 'watch_over_notifications';
  static const String _messageChannelId = 'watch_over_message_notifications';

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
    // 로컬 알림 초기화
    await _initLocalNotifications();

    // 설정 불러오기
    await loadSettings();
    debugPrint('✅ NotificationService 초기화 완료');
  }

  // 로컬 알림 초기화
  Future<void> _initLocalNotifications() async {
    try {
      // 안드로이드 설정
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // iOS 설정
      final DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
        onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
      );

      // 초기화 설정
      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // 알림 플러그인 초기화
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );

      // 권한 요청 (iOS)
      if (Platform.isIOS) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      }

      debugPrint('✅ 로컬 알림 서비스 초기화 완료');
    } catch (e) {
      debugPrint('⚠️ 로컬 알림 초기화 오류: $e');
    }
  }

  // iOS 10 이하에서 알림을 탭했을 때의 콜백
  void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    debugPrint('🔔 iOS 알림 수신: $title - $body');
    // 필요한 경우 이 콜백에서 알림 처리 로직 구현
  }

  // 알림을 탭했을 때의 콜백
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint('🔔 알림 탭: ${response.payload}');
    // 알림 탭 처리 로직
    if (response.payload != null) {
      if (response.payload!.startsWith('message:')) {
        // 메시지 알림인 경우 메시지 화면으로 이동
        final senderId = response.payload!.substring(8);
        Get.toNamed('/messages', arguments: {'senderId': senderId});
      } else if (response.payload!.startsWith('location:')) {
        // 위치 공유 알림인 경우 위치 추적 화면으로 이동
        // 형식: location:start/stop:senderId:locationId
        final parts = response.payload!.split(':');
        if (parts.length >= 3) {
          final action = parts[1]; // start 또는 stop
          final senderId = parts[2]; // 위치 공유 발신자 ID

          if (action == 'start') {
            // 위치 추적 화면으로 이동
            Get.toNamed('/location-tracking', arguments: {
              'userId': senderId,
              // 사용자 이름은 이동 후 화면에서 조회
            });
            debugPrint('🗺️ 위치 추적 화면으로 이동: userId=$senderId');
          }
        }
      }
    }
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
    // 권한 재요청
    if (Platform.isAndroid) {
      // 버전 15.1.3에서는 requestNotificationsPermission 대신 다음 코드 사용
      // 안드로이드 13 이상에서는 권한 요청 필요없음 (자동으로 처리됨)
      debugPrint('✅ 안드로이드 알림 권한 설정 완료');
    } else if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? iosPlugin =
          flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    debugPrint('✅ 알림 서비스 활성화됨');
  }

  // 알림 비활성화 처리
  Future<void> _disableNotifications() async {
    // 기존 알림 모두 취소
    await flutterLocalNotificationsPlugin.cancelAll();
    debugPrint('✅ 알림 서비스 비활성화됨');
  }

  // 앱 알림 보내기 (로컬 알림)
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

    try {
      // 안드로이드용 알림 세부 설정
      AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        _channelId,
        'Watch Over 알림',
        channelDescription: '앱 알림 채널',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        icon: '@mipmap/launcher_icon',
      );

      // iOS용 알림 세부 설정
      DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );

      // 플랫폼별 설정 통합
      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // 알림 표시
      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      debugPrint('✅ 로컬 알림 표시: $title - $body');
    } catch (e) {
      debugPrint('⚠️ 로컬 알림 표시 오류: $e');
    }
  }

  // 메시지 알림 보내기
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

    try {
      // 안드로이드용 알림 세부 설정
      AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        _messageChannelId,
        '메시지 알림',
        channelDescription: '새 메시지 수신 알림',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        icon: '@mipmap/launcher_icon',
        category: AndroidNotificationCategory.message,
        styleInformation: BigTextStyleInformation(messageContent),
      );

      // iOS용 알림 세부 설정
      DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.active,
      );

      // 플랫폼별 설정 통합
      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // 메시지 내용이 너무 길면 일부만 표시
      String displayContent = messageContent;
      if (messageContent.length > 100) {
        displayContent = '${messageContent.substring(0, 97)}...';
      }

      // 알림 표시
      await flutterLocalNotificationsPlugin.show(
        id,
        '$senderName님의 새 메시지',
        displayContent,
        platformChannelSpecifics,
        payload: 'message:$senderId',
      );

      debugPrint('✅ 메시지 알림 표시: $senderName - $displayContent');
    } catch (e) {
      debugPrint('⚠️ 메시지 알림 표시 오류: $e');
    }
  }

  // 위치 공유 알림 표시
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

    try {
      // 안드로이드용 알림 세부 설정
      AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        _channelId,
        '위치 공유 알림',
        channelDescription: '위치 공유 알림 채널',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        icon: '@mipmap/launcher_icon',
        color: const Color(0xFF4285F4), // 파란색 (위치 관련)
      );

      // iOS용 알림 세부 설정
      DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      // 플랫폼별 설정 통합
      NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      // 알림 표시
      await flutterLocalNotificationsPlugin.show(
        id,
        '위치 공유 알림',
        message,
        platformChannelSpecifics,
        payload:
            'location:${isStarting ? "start" : "stop"}:$senderId:${locationId ?? ""}',
      );

      debugPrint('✅ 위치 공유 알림 표시: $senderName - $message');
    } catch (e) {
      debugPrint('⚠️ 위치 공유 알림 표시 오류: $e');
    }
  }
}
