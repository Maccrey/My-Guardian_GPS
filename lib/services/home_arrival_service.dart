import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:watch_over/services/location_service.dart';
import 'package:watch_over/services/auth_service.dart';
import 'package:watch_over/services/message_service.dart';
import 'package:watch_over/services/emergency_contact_service.dart';

/// 귀가 알림 및 안전 도착 서비스
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
  final RxString arrivalMessage = '집에 안전하게 도착했습니다.'.obs;
  final RxInt homeRadiusMeters = 50.obs; // 집 근처로 간주할 반경(미터)

  // 상수
  static const String PREF_TRACKING_ENABLED = 'home_arrival_tracking_enabled';
  static const String PREF_RECIPIENT_IDS = 'home_arrival_recipient_ids';
  static const String PREF_HOME_RADIUS = 'home_arrival_radius';
  static const String PREF_ARRIVAL_MESSAGE = 'home_arrival_message';
  static const String NOTIFICATION_CHANNEL_ID = 'home_arrival_notification';

  // 알림 플러그인 (임시로 주석 처리)
  // final FlutterLocalNotificationsPlugin _notificationsPlugin =
  //     FlutterLocalNotificationsPlugin();

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

      // 알림 초기화 (임시로 주석 처리)
      // await _initNotifications();

      // 저장된 설정 로드
      await _loadSettings();

      debugPrint('✅ HomeArrivalService 초기화 성공');
    } catch (e) {
      debugPrint('❌ HomeArrivalService 초기화 오류: $e');
    }
  }

  // 알림 초기화 (임시로 주석 처리)
  /*
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(initializationSettings);

    // Android용 알림 채널 생성
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      NOTIFICATION_CHANNEL_ID,
      '귀가 알림 추적',
      description: '귀가 알림 서비스가 위치를 추적 중입니다.',
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('✅ 알림 초기화 완료');
  }
  */

  // 설정 로드
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 귀가 추적 활성화 여부
      isTrackingEnabled.value = prefs.getBool(PREF_TRACKING_ENABLED) ?? false;

      // 집 반경
      homeRadiusMeters.value = prefs.getInt(PREF_HOME_RADIUS) ?? 50;

      // 도착 메시지
      arrivalMessage.value =
          prefs.getString(PREF_ARRIVAL_MESSAGE) ?? '집에 안전하게 도착했습니다.';

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

      // 집 반경
      await prefs.setInt(PREF_HOME_RADIUS, homeRadiusMeters.value);

      // 도착 메시지
      await prefs.setString(PREF_ARRIVAL_MESSAGE, arrivalMessage.value);

      // 수신자 ID 목록
      await prefs.setStringList(PREF_RECIPIENT_IDS, messageRecipientIds);

      debugPrint('✅ HomeArrivalService 설정 저장 완료');
    } catch (e) {
      debugPrint('❌ HomeArrivalService 설정 저장 오류: $e');
    }
  }

  // 앱 재시작 시 도착 알림 확인 및 처리
  Future<void> checkPendingArrivalNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isPending =
          prefs.getBool('arrival_notification_pending') ?? false;

      if (isPending) {
        debugPrint('🔍 보류 중인 귀가 알림 발견');

        // 발신 정보 가져오기
        final String message =
            prefs.getString('arrival_notification_message') ??
                arrivalMessage.value;
        final List<String> recipients =
            prefs.getStringList('arrival_notification_recipients') ?? [];

        // 빈 수신자 목록 확인
        if (recipients.isEmpty) {
          debugPrint('⚠️ 수신자 목록이 비어 있어 알림을 보낼 수 없습니다.');
          await prefs.setBool('arrival_notification_pending', false);
          return;
        }

        // 메시지 발송
        final AuthService authService = Get.find<AuthService>();
        final MessageService messageService = Get.find<MessageService>();

        for (final recipientId in recipients) {
          try {
            await messageService.sendMessage(
              receiverId: recipientId,
              content: message,
              messageType: 'home_arrival',
            );
            debugPrint('✅ 귀가 알림 메시지 전송 성공: $recipientId');
          } catch (e) {
            debugPrint('❌ 귀가 알림 메시지 전송 실패: $e');
          }
        }

        // 보류 중 플래그 해제
        await prefs.setBool('arrival_notification_pending', false);

        debugPrint('✅ 보류 중인 귀가 알림 처리 완료');
      }
    } catch (e) {
      debugPrint('❌ 보류 중인 귀가 알림 처리 오류: $e');
    }
  }

  // 추적 상태 업데이트
  Future<void> refreshTrackingStatus() async {
    debugPrint('🔄 HomeArrivalService: 추적 상태 확인 중');

    try {
      // 현재 상태 확인
      final prefs = await SharedPreferences.getInstance();
      final savedIsTracking = prefs.getBool(PREF_TRACKING_ENABLED) ?? false;

      // 상태 불일치 확인 및 수정
      if (savedIsTracking != isTrackingEnabled.value) {
        debugPrint(
            '⚠️ 저장된 추적 상태 불일치 감지: UI=${isTrackingEnabled.value}, 저장됨=$savedIsTracking');
        isTrackingEnabled.value = savedIsTracking;
      }

      // 추적 중이면 상태 업데이트
      if (isTrackingEnabled.value) {
        isArrivingHome.value = true;
        trackingStatus.value = '집 근처 감지 중...';
      } else {
        isArrivingHome.value = false;
        trackingStatus.value = '추적 비활성화';
      }

      debugPrint('✅ 추적 상태 업데이트 완료: 추적 중=${isTrackingEnabled.value}');
    } catch (e) {
      debugPrint('❌ 추적 상태 업데이트 오류: $e');
    }
  }

  // 추적 중지
  Future<void> stopTracking() async {
    try {
      // 먼저 현재 상태 확인 (알림 표시 조건용)
      final wasTracking = isTrackingEnabled.value;

      // 추적 상태 업데이트
      isTrackingEnabled.value = false;
      isArrivingHome.value = false;
      trackingStatus.value = '추적 비활성화';

      // 완료 알림 표시 (추적이 실제로 활성화되어 있었을 때만)
      if (wasTracking) {
        // 알림 플러그인 문제로 임시 주석 처리
        // await _showHomeArrivalCompletionNotification();
        debugPrint('✅ [임시] 귀가 알림 완료 알림 (콘솔에만 표시)');
      }

      // 설정 저장
      await _saveSettings();

      debugPrint('✅ 귀가 추적 중지');
    } catch (e) {
      debugPrint('❌ 귀가 추적 중지 오류: $e');
    }
  }

  // 추적 시작
  Future<bool> startTracking() async {
    try {
      // 이미 추적 중이면 무시
      if (isTrackingEnabled.value) {
        debugPrint('⚠️ 이미 귀가 추적 중입니다.');
        return true;
      }

      // 위치 권한 확인
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        debugPrint('❌ 위치 권한이 없어 귀가 추적을 시작할 수 없습니다.');
        return false;
      }

      // 수신자 목록 확인
      if (messageRecipientIds.isEmpty) {
        // 비상 연락처에서 첫 번째 연락처를 기본으로 설정
        final List<dynamic> contacts = _emergencyContactService.contacts;
        if (contacts.isNotEmpty) {
          messageRecipientIds.add(contacts.first.id);
        }
      }

      // 추적 상태 업데이트
      isTrackingEnabled.value = true;
      isArrivingHome.value = true;
      trackingStatus.value = '집 근처 감지 중...';

      // 설정 저장
      await _saveSettings();

      debugPrint('✅ 귀가 추적 시작');
      return true;
    } catch (e) {
      debugPrint('❌ 귀가 추적 시작 오류: $e');
      return false;
    }
  }

  // 위치 권한 확인
  Future<bool> _checkLocationPermission() async {
    try {
      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ 위치 서비스가 비활성화되어 있습니다.');
        return false;
      }

      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // 권한이 없으면 요청
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('❌ 위치 권한이 거부되었습니다.');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ 위치 권한이 영구적으로 거부되었습니다.');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ 위치 권한 확인 오류: $e');
      return false;
    }
  }

  // 귀가 알림 완료 알림 표시 (임시로 주석 처리)
  /*
  Future<void> _showHomeArrivalCompletionNotification() async {
    try {
      // Android 알림 세부 정보
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'home_arrival_completion_channel',
        '귀가 알림 완료',
        channelDescription: '귀가 알림 서비스 완료 알림',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      // iOS 알림 세부 정보
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      // 플랫폼 세부 정보
      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 알림 표시
      await _notificationsPlugin.show(
        2, // 알림 ID
        '귀가 알림 완료',
        '귀가 알림 서비스가 중지되었습니다.',
        platformDetails,
      );

      debugPrint('✅ 귀가 알림 완료 알림 표시');
    } catch (e) {
      debugPrint('❌ 귀가 알림 완료 알림 표시 오류: $e');
    }
  }
  */

  // 메시지 수신자 설정
  Future<void> setMessageRecipients(List<String> recipientIds) async {
    messageRecipientIds.value = recipientIds;
    await _saveSettings();
    debugPrint('✅ 메시지 수신자 설정 완료: ${recipientIds.length}명');
  }

  // 도착 메시지 설정
  Future<void> setArrivalMessage(String message) async {
    arrivalMessage.value = message;
    await _saveSettings();
    debugPrint('✅ 도착 메시지 설정 완료');
  }

  // 집 반경 설정
  Future<void> setHomeRadius(int radiusMeters) async {
    homeRadiusMeters.value = radiusMeters;
    await _saveSettings();
    debugPrint('✅ 집 반경 설정 완료: ${radiusMeters}m');
  }

  // 서비스 종료 시 정리
  @override
  void onClose() {
    super.onClose();
  }
}
