import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:watch_over/services/background_location_service.dart';
import 'package:watch_over/services/background_task_service.dart';
import 'package:watch_over/services/home_location_service.dart';
import 'package:watch_over/services/message_service.dart';
import 'package:watch_over/services/notification_service.dart';
import 'package:watch_over/services/location_service.dart';
import 'package:watch_over/services/auth_service.dart';
import 'package:watch_over/services/emergency_contact_service.dart';
import 'package:watch_over/services/geofence_service.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:watch_over/models/home_location_model.dart';
import 'package:watch_over/models/user_model.dart';

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
  final RxInt homeRadiusMeters = 30.obs; // 집 근처로 간주할 반경(미터)
  final RxString lastEventMessage = ''.obs;

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
  HomeLocationService? _homeLocationService;
  late GeofenceService _geofenceService;

  // 백그라운드 서비스
  late BackgroundLocationService _backgroundLocationService;
  late BackgroundTaskService _backgroundTaskService;
  late NotificationService _notificationService;

  // 백그라운드 모드 지원 상태
  final RxBool isBackgroundServiceRunning = false.obs;
  final RxBool isBackgroundEnabled = true.obs;

  // 위치 추적 설정
  final int _defaultRadiusMeters = 30; // 기본 반경 30m
  final int _defaultTrackingIntervalSeconds = 10; // 10초마다 위치 확인으로 변경
  int _trackingIntervalSeconds = 10; // 기본값 10초로 변경

  Timer? _locationTrackingTimer;
  bool _hasSentArrivalMessage = false;
  final RxDouble _distanceToHome = double.maxFinite.obs;

  // 초기화
  Future<void> _init() async {
    try {
      // 1. 필요한 서비스들을 먼저 확인하고 없으면 등록
      if (!Get.isRegistered<GeofenceService>()) {
        debugPrint('🔄 GeofenceService 등록 시도 중...');
        Get.put(GeofenceService(), permanent: true);
      }

      // GeofenceService 초기화 상태 명시적 확인
      try {
        _geofenceService = Get.find<GeofenceService>();
        debugPrint('✅ GeofenceService 찾기 성공');
      } catch (e) {
        debugPrint('❌ GeofenceService를 찾을 수 없음: $e');
        Get.put(GeofenceService(), permanent: true);
        _geofenceService = Get.find<GeofenceService>();
        debugPrint('✅ GeofenceService 재등록 성공');
      }

      // 서비스들이 모두 등록되어 있는지 확인
      if (!Get.isRegistered<LocationService>()) {
        debugPrint(
            '❌ LocationService가 등록되지 않았습니다. 먼저 LocationService를 초기화해주세요.');
        throw Exception('LocationService 미등록');
      }

      if (!Get.isRegistered<AuthService>()) {
        debugPrint('❌ AuthService가 등록되지 않았습니다. 먼저 AuthService를 초기화해주세요.');
        throw Exception('AuthService 미등록');
      }

      if (!Get.isRegistered<MessageService>()) {
        debugPrint('❌ MessageService가 등록되지 않았습니다. 먼저 MessageService를 초기화해주세요.');
        throw Exception('MessageService 미등록');
      }

      // 2. 서비스 찾기
      _locationService = Get.find<LocationService>();
      _authService = Get.find<AuthService>();
      _messageService = Get.find<MessageService>();

      // 3. EmergencyContactService 안전하게 등록
      if (!Get.isRegistered<EmergencyContactService>()) {
        Get.put(EmergencyContactService(), permanent: true);
      }
      _emergencyContactService = Get.find<EmergencyContactService>();

      // 4. HomeLocationService 초기화
      _homeLocationService = await HomeLocationService.getInstance();

      // 5. 알림 서비스 초기화
      _notificationService = await NotificationService.getInstance();
      await _notificationService.setupLocalNotifications();

      // 6. 백그라운드 서비스 초기화
      _backgroundLocationService = BackgroundLocationService.instance;
      await _backgroundLocationService.init();
      isBackgroundServiceRunning.value =
          _backgroundLocationService.isRunning.value;

      // 7. 백그라운드 작업 서비스 초기화
      _backgroundTaskService = BackgroundTaskService.instance;
      await _backgroundTaskService.init();

      // 8. 이벤트 핸들러 등록 (GeofenceService가 확실히 초기화된 후)
      if (_geofenceService != null) {
        _geofenceService.setEventHandler(_onGeofenceEvent);
      } else {
        debugPrint('⚠️ _geofenceService가 null입니다. 이벤트 핸들러를 등록할 수 없습니다.');
      }

      // 9. 설정 로드
      await _loadSettings();

      // 10. 백그라운드 서비스 상태 업데이트 리스너 등록
      _backgroundLocationService.isRunning.listen((running) {
        isBackgroundServiceRunning.value = running;
        debugPrint('📱 백그라운드 서비스 상태 변경: $running');
      });

      debugPrint('✅ HomeArrivalService 초기화 성공');
    } catch (e, stack) {
      debugPrint('❌ HomeArrivalService 초기화 오류: $e\n$stack');
      lastEventMessage.value = '귀가알림 서비스 초기화 오류: $e';
      rethrow; // 오류를 다시 던져서 호출자에게 알림
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
      homeRadiusMeters.value = prefs.getInt(PREF_HOME_RADIUS) ?? 30;

      // 도착 메시지
      arrivalMessage.value =
          prefs.getString(PREF_ARRIVAL_MESSAGE) ?? '집에 안전하게 도착했습니다.';

      // 메시지 수신자 ID 목록
      final recipientIdsJson = prefs.getStringList(PREF_RECIPIENT_IDS) ?? [];
      messageRecipientIds.value = recipientIdsJson;

      // 백그라운드 모드 설정
      isBackgroundEnabled.value =
          prefs.getBool('home_arrival_background_enabled') ?? true;

      // 백그라운드 서비스 상태 확인
      await checkBackgroundServiceStatus();

      debugPrint('✅ HomeArrivalService 설정 로드 완료');
    } catch (e) {
      debugPrint('❌ HomeArrivalService 설정 로드 오류: $e');
    }
  }

  // 설정 저장
  Future<bool> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 알림 메시지 저장
      await prefs.setString(PREF_ARRIVAL_MESSAGE, arrivalMessage.value);

      // 알림 활성화 상태 저장
      await prefs.setBool(PREF_TRACKING_ENABLED, isTrackingEnabled.value);

      // 수신자 목록 저장
      await prefs.setStringList(
          PREF_RECIPIENT_IDS, messageRecipientIds.toList());

      // 집 반경 저장
      await prefs.setInt(PREF_HOME_RADIUS, homeRadiusMeters.value);

      // 백그라운드 모드 설정 저장
      await prefs.setBool(
          'home_arrival_background_enabled', isBackgroundEnabled.value);

      debugPrint('✅ HomeArrivalService 설정 저장 완료');
      return true;
    } catch (e) {
      debugPrint('❌ HomeArrivalService 설정 저장 오류: $e');
      return false;
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
        int successCount = 0;

        debugPrint('📤 귀가 알림 메시지 전송 시도 (수신자: ${recipients.length}명)');

        for (final recipientId in recipients) {
          try {
            await messageService.sendMessage(
              receiverId: recipientId,
              content: message,
              messageType: 'home_arrival',
            );
            successCount++;
            debugPrint('✅ 귀가 알림 메시지 전송 성공: $recipientId');
          } catch (e) {
            debugPrint('❌ 귀가 알림 메시지 전송 실패: $e');
            // 실패해도 계속 진행
          }
        }

        // 보류 중 플래그 해제
        await prefs.setBool('arrival_notification_pending', false);

        // 사용자에게 알림 표시
        if (successCount > 0) {
          Get.snackbar(
            '귀가 알림 전송 완료',
            '집 도착 알림이 전송되었습니다.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade600,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            '귀가 알림 전송 실패',
            '메시지 전송에 실패했습니다. 네트워크 상태를 확인하세요.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
          );
        }

        debugPrint(
            '✅ 보류 중인 귀가 알림 처리 완료 (성공: $successCount/${recipients.length})');
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

  // 집 위치 등록 시 지오펜스 등록
  Future<void> registerHomeGeofence() async {
    try {
      final homeLocation = _homeLocationService?.getSelectedHomeLocation();
      if (homeLocation == null) {
        debugPrint('❌ 지오펜스 등록을 위한 홈 위치 정보가 없습니다.');
        return;
      }

      // 지오펜스 이벤트를 수신하기 위한 방송 수신기 등록
      debugPrint(
          '✅ 홈 지오펜스 등록: ${homeLocation.name} (${homeLocation.latitude}, ${homeLocation.longitude})');
    } catch (e) {
      debugPrint('❌ 홈 지오펜스 등록 오류: $e');
    }
  }

  // 지오펜스 이벤트 핸들러
  void _onGeofenceEvent(GeofenceEvent event) async {
    if (event.id == 'home' && event.eventType == GeofenceEventType.enter) {
      debugPrint('🏠 집 반경 진입 지오펜스 이벤트 감지, 메시지 전송 트리거');
      if (!_hasSentArrivalMessage) {
        _hasSentArrivalMessage = true;
        await _sendArrivalMessage();
        lastEventMessage.value = '집에 도착하여 귀가알림을 전송했습니다.';
        try {
          Get.snackbar(
            '귀가 완료',
            '집에 도착하여 귀가알림을 전송했습니다.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            borderRadius: 8,
            icon: const Icon(Icons.home, color: Colors.white),
          );
        } catch (e) {
          debugPrint('⚠️ 스낵바 표시 오류 (무시됨): $e');
        }
      }
    }
  }

  // 메시지 전송 로직
  Future<void> _sendArrivalMessage() async {
    // 집 위치 정보 가져오기
    final homeLocation = _homeLocationService?.getSelectedHomeLocation();
    if (homeLocation == null) {
      debugPrint('❌ 선택된 집 위치 정보가 없어 메시지를 보낼 수 없습니다.');
      return;
    }

    // 수신자 ID가 없는 경우 확인
    if (messageRecipientIds.isEmpty) {
      debugPrint('❌ 메시지 수신자가 지정되지 않았습니다. 메시지를 보낼 수 없습니다.');
      lastEventMessage.value = '메시지 수신자가 지정되지 않아 알림을 보낼 수 없습니다.';
      return;
    }

    // EmergencyContactService null 체크
    if (_emergencyContactService == null) {
      debugPrint('❌ EmergencyContactService가 초기화되지 않았습니다.');
      lastEventMessage.value = '긴급 연락처 서비스가 초기화되지 않았습니다.';
      return;
    }

    debugPrint('📤 귀가 알림 메시지 전송 시작: ${messageRecipientIds.length}명의 수신자');
    debugPrint('📤 수신자 목록: ${messageRecipientIds.join(", ")}');
    debugPrint('📤 메시지 내용: ${arrivalMessage.value}');

    bool atLeastOneSuccess = false;

    for (final recipientId in messageRecipientIds) {
      try {
        debugPrint('📤 귀가 알림 메시지 전송 시도: $recipientId');

        if (recipientId.isEmpty) {
          debugPrint('⚠️ 수신자 ID가 비어 있습니다. 건너뜁니다.');
          continue;
        }

        // 긴급 연락처 객체 찾기
        final contact = _emergencyContactService.contacts
            .firstWhereOrNull((c) => c.id == recipientId);
        if (contact != null) {
          debugPrint('🔍 수신자 타입: 긴급 연락처 - ${contact.name} (ID: ${contact.id})');
          debugPrint(
              '🔍 긴급 연락처 정보: 앱사용자=${contact.isAppUser}, userId=${contact.userId}');

          if (contact.isAppUser &&
              contact.userId != null &&
              contact.userId!.isNotEmpty) {
            // 앱 사용자로 등록된 긴급 연락처라면 userId로 메시지 전송
            debugPrint('📤 앱 사용자 긴급 연락처로 메시지 전송 시도: userId=${contact.userId}');

            // 위치 정보를 포함한 JSON 메시지 생성
            final locationContent = jsonEncode({
              'type': 'arrival_notification',
              'latitude': homeLocation.latitude,
              'longitude': homeLocation.longitude,
              'address': homeLocation.address,
              'name': homeLocation.name,
              'message': arrivalMessage.value,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });

            // 직접 메시지 서비스를 통해 전송
            final success = await _messageService.sendMessage(
              receiverId: contact.userId!,
              content: locationContent,
              messageType: 'location_arrival',
            );

            if (success) {
              debugPrint('✅ 긴급 연락처(앱 사용자) ${contact.name}에게 귀가 알림 메시지 전송 성공');
              lastEventMessage.value = '${contact.name}님에게 귀가 알림을 전송했습니다.';
              atLeastOneSuccess = true;
            } else {
              debugPrint('❌ 긴급 연락처(앱 사용자) ${contact.name}에게 메시지 전송 실패');
              throw Exception('긴급 연락처(앱 사용자) 메시지 전송 실패');
            }
          } else {
            // 일반 연락처(앱 사용자가 아님) - 메시지 전송 불가
            debugPrint(
                '⚠️ 일반 연락처(앱 사용자가 아님)에는 메시지를 보낼 수 없습니다: ${contact.name}');
            continue;
          }
        } else {
          // 앱 사용자(긴급 연락처가 아님)
          debugPrint('🔍 수신자 타입: 앱 사용자 (ID: $recipientId)');

          // 위치 정보를 포함한 JSON 메시지 생성
          final locationContent = jsonEncode({
            'type': 'arrival_notification',
            'latitude': homeLocation.latitude,
            'longitude': homeLocation.longitude,
            'address': homeLocation.address,
            'name': homeLocation.name,
            'message': arrivalMessage.value,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

          // 직접 메시지 서비스를 통해 전송
          final success = await _messageService.sendMessage(
            receiverId: recipientId,
            content: locationContent,
            messageType: 'location_arrival',
          );

          if (success) {
            debugPrint('✅ 앱 사용자에게 귀가 알림 메시지 전송 성공: $recipientId');
            lastEventMessage.value = '앱 사용자에게 귀가 알림 메시지 전송 성공';
            atLeastOneSuccess = true;
          } else {
            debugPrint('❌ 앱 사용자에게 메시지 전송 실패: $recipientId');
            throw Exception('앱 사용자 메시지 전송 실패');
          }
        }
      } catch (e, stack) {
        debugPrint('❌ 귀가 알림 메시지 전송 실패: $e\n$stack');
        lastEventMessage.value = '귀가 알림 메시지 전송 실패: $e';
      }
    }

    if (atLeastOneSuccess) {
      debugPrint('✅ 적어도 하나의 메시지가 성공적으로 전송되었습니다.');
    } else {
      debugPrint('❌ 모든 메시지 전송이 실패했습니다.');
      lastEventMessage.value = '모든 귀가 알림 메시지 전송이 실패했습니다.';
    }
  }

  // 추적 상태 업데이트
  Future<void> _triggerHomeArrival() async {
    try {
      // 이미 알림을 보냈다면 중복 발송 방지
      if (_hasSentArrivalMessage) {
        debugPrint('⚠️ 이미 귀가 알림을 보냈습니다. 중복 발송을 방지합니다.');
        return;
      }

      // 집 위치 정보 가져오기
      final homeLocation = _homeLocationService?.getSelectedHomeLocation();
      if (homeLocation == null) {
        debugPrint('❌ 선택된 집 위치 정보가 없어 귀가 알림을 트리거할 수 없습니다.');
        return;
      }

      // 알림 상태 업데이트
      _hasSentArrivalMessage = true;
      trackingStatus.value = '집 도착 감지됨';
      debugPrint('🏠 집 도착 감지! 알림 메시지 전송 중...');

      // 진동 피드백 (UI 스레드에서 실행)
      try {
        await HapticFeedback.vibrate();
      } catch (e) {
        debugPrint('⚠️ 진동 피드백 오류 (무시됨): $e');
      }

      // 메시지 전송
      bool messageSent = false;
      String errorDetails = '';

      // 각 수신자에게 메시지 전송 시도
      for (final recipientId in messageRecipientIds) {
        try {
          // 집 위치 정보에서 메시지 데이터 구성
          final locationContent = jsonEncode({
            'type': 'arrival_notification',
            'latitude': homeLocation.latitude,
            'longitude': homeLocation.longitude,
            'address': homeLocation.address,
            'name': homeLocation.name,
            'message': arrivalMessage.value,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });

          final success = await _messageService.sendMessage(
            receiverId: recipientId,
            content: locationContent,
            messageType: 'location_arrival',
          );

          if (success) {
            messageSent = true;
            debugPrint('✅ $recipientId에게 귀가 알림 전송 성공');
          } else {
            errorDetails += ' $recipientId 전송 실패;';
            debugPrint('❌ $recipientId에게 귀가 알림 전송 실패');
          }
        } catch (e) {
          errorDetails += ' $recipientId 오류: $e;';
          debugPrint('❌ $recipientId에게 귀가 알림 전송 중 오류: $e');
        }
      }

      // 알림 메시지 표시
      if (messageSent) {
        trackingStatus.value = '귀가 알림 전송됨';
        lastEventMessage.value = '귀가 알림이 전송되었습니다.';

        try {
          // 로컬 알림 표시
          final notificationService = await NotificationService.getInstance();
          await notificationService.showNotification(
            id: 9999,
            title: '🏠 집에 도착했습니다',
            body: '귀가 알림이 전송되었습니다.',
            payload: 'home_arrival_success',
          );
        } catch (e) {
          debugPrint('⚠️ 로컬 알림 표시 오류 (무시됨): $e');
        }

        // UI 알림 표시
        try {
          Get.snackbar(
            '귀가 알림',
            '집에 도착하여 귀가 알림이 전송되었습니다.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.green.shade600,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            borderRadius: 8,
          );
        } catch (e) {
          debugPrint('⚠️ 스낵바 표시 오류 (무시됨): $e');
        }

        // 자동 추적 중지
        await Future.delayed(const Duration(seconds: 3));
        await stopTracking();
      } else {
        trackingStatus.value = '귀가 알림 전송 실패';
        lastEventMessage.value = '귀가 알림 전송에 실패했습니다: $errorDetails';

        // 알림 상태 재설정 (재시도를 위해)
        _hasSentArrivalMessage = false;

        try {
          Get.snackbar(
            '귀가 알림 실패',
            '귀가 알림 전송에 실패했습니다. 다시 시도합니다.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            borderRadius: 8,
          );
        } catch (e) {
          debugPrint('⚠️ 스낵바 표시 오류 (무시됨): $e');
        }
      }
    } catch (e) {
      debugPrint('❌ 귀가 알림 트리거 오류: $e');
      lastEventMessage.value = '귀가 알림 트리거 오류: $e';
      _hasSentArrivalMessage = false; // 재시도를 위해 초기화
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

  // 추적 중지
  Future<bool> stopTracking() async {
    try {
      isTrackingEnabled.value = false;
      isArrivingHome.value = false;
      trackingStatus.value = '귀가 추적 중지됨';

      // 백그라운드 서비스 중지
      if (isBackgroundServiceRunning.value) {
        final stopped = await _backgroundLocationService.stopService();
        if (stopped) {
          debugPrint('✅ 백그라운드 위치 서비스 중지됨');
        } else {
          debugPrint('⚠️ 백그라운드 위치 서비스 중지 실패');
        }
        isBackgroundServiceRunning.value = false;
      }

      // 백그라운드 작업 중지
      await _backgroundTaskService.cancelAllTasks();

      // 위치 추적 타이머 중지
      _locationTrackingTimer?.cancel();
      _locationTrackingTimer = null;

      // 설정 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('home_arrival_tracking_enabled', false);

      debugPrint('✅ 귀가 추적 중지됨');
      return true;
    } catch (e) {
      debugPrint('❌ 귀가 추적 중지 오류: $e');
      return false;
    }
  }

  // 백그라운드 서비스 상태 확인
  Future<void> checkBackgroundServiceStatus() async {
    try {
      // 백그라운드 위치 서비스 상태 확인
      isBackgroundServiceRunning.value =
          await _backgroundLocationService.isRunning.value;

      debugPrint(
          '✅ 백그라운드 서비스 상태 확인: ${_backgroundLocationService.isRunning.value}');
    } catch (e) {
      debugPrint('❌ 백그라운드 서비스 상태 확인 오류: $e');
    }
  }

  // 메시지 수신자 설정
  Future<void> setMessageRecipients(List<String> recipientIds) async {
    if (recipientIds.isEmpty) {
      debugPrint('⚠️ 빈 수신자 목록이 전달되었습니다.');
      return;
    }

    // 유효하지 않은 ID 필터링
    final validRecipientIds =
        recipientIds.where((id) => id.isNotEmpty).toList();

    if (validRecipientIds.isEmpty) {
      debugPrint('❌ 유효한 수신자 ID가 없습니다.');
      return;
    }

    // 기존 수신자 목록 백업
    final previousRecipients = List<String>.from(messageRecipientIds);

    // 새 수신자 목록 설정
    messageRecipientIds.value = validRecipientIds;

    // 설정 저장
    final success = await _saveSettings();

    if (success) {
      debugPrint('✅ 메시지 수신자 설정 완료: ${validRecipientIds.length}명');
      debugPrint('👥 수신자 목록: ${validRecipientIds.join(", ")}');

      // 이전 목록과 비교
      if (!_listEquals(previousRecipients, validRecipientIds)) {
        debugPrint('🔄 수신자 목록이 변경되었습니다:');
        debugPrint('   이전: ${previousRecipients.join(", ")}');
        debugPrint('   현재: ${validRecipientIds.join(", ")}');
      } else {
        debugPrint('ℹ️ 수신자 목록이 변경되지 않았습니다.');
      }
    } else {
      debugPrint('❌ 메시지 수신자 설정 저장 실패');
      // 실패 시 복원
      messageRecipientIds.value = previousRecipients;
    }
  }

  // 두 리스트가 동일한지 확인하는 헬퍼 함수
  bool _listEquals(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  // 도착 메시지 설정
  Future<void> setArrivalMessage(String message) async {
    // 기존 메시지 내용을 JSON 형식의 content에 포함된 message 필드로 처리
    arrivalMessage.value = message;
    await _saveSettings();
    debugPrint('✅ 도착 메시지 설정 완료: $message');
  }

  // 추적 시작
  Future<bool> startTracking() async {
    try {
      // 이미 추적 중이면 중지 후 재시작
      if (isTrackingEnabled.value) {
        await stopTracking();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 위치 서비스 가용성 확인
      final locationPermission = await _checkLocationPermission();
      if (!locationPermission) {
        debugPrint('❌ 위치 권한이 없어 귀가 추적을 시작할 수 없습니다.');
        lastEventMessage.value = '위치 권한이 없어 귀가 추적을 시작할 수 없습니다.';
        return false;
      }

      // 홈 위치 정보 확인
      final homeLocation = _homeLocationService?.getSelectedHomeLocation();
      if (homeLocation == null) {
        debugPrint('❌ 설정된 집 위치가 없어 귀가 추적을 시작할 수 없습니다.');
        lastEventMessage.value = '설정된 집 위치가 없어 귀가 추적을 시작할 수 없습니다.';
        return false;
      }

      // 위치 서비스 재시작
      final locationService = Get.find<LocationService>();
      locationService.stopTracking(); // 먼저 중지
      await Future.delayed(const Duration(milliseconds: 500)); // 잠시 대기
      locationService.startTracking(); // 다시 시작
      debugPrint('✅ [HomeArrivalService] 위치 서비스 재시작 완료');

      // 수신자 확인
      if (messageRecipientIds.isEmpty) {
        debugPrint('⚠️ 메시지 수신자가 없습니다. 긴급 연락처에서 첫 번째 연락처를 사용합니다.');
        final contacts = _emergencyContactService.contacts;
        if (contacts.isNotEmpty) {
          messageRecipientIds.add(contacts.first.id);
          debugPrint('✅ 긴급 연락처 추가됨: ${contacts.first.id}');
        } else {
          debugPrint('❌ 사용 가능한 긴급 연락처가 없습니다.');
          lastEventMessage.value = '메시지 수신자가 지정되지 않았습니다.';
          return false;
        }
      }

      // 추적 상태 업데이트
      isTrackingEnabled.value = true;
      isArrivingHome.value = true;
      trackingStatus.value = '집 근처 감지 중...';

      // 홈 위치 정보 직접 저장 (백그라운드 서비스를 위한 백업)
      if (homeLocation != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('home_latitude', homeLocation.latitude);
        await prefs.setDouble('home_longitude', homeLocation.longitude);
        await prefs.setStringList(
            'home_arrival_recipient_ids', messageRecipientIds);
        await prefs.setString('home_arrival_message', arrivalMessage.value);
        await prefs.setBool('home_arrival_tracking_enabled', true);
        await prefs.setInt('home_arrival_radius', homeRadiusMeters.value);

        debugPrint(
            '✅ 백그라운드 서비스를 위한 홈 위치 정보 저장: (${homeLocation.latitude}, ${homeLocation.longitude})');
        debugPrint(
            '✅ 백그라운드 서비스를 위한 수신자 정보 저장: ${messageRecipientIds.join(", ")}');
        debugPrint(
            '✅ 백그라운드 서비스를 위한 설정 저장: 반경=${homeRadiusMeters.value}m, 메시지=${arrivalMessage.value}');
      }

      await _saveSettings();
      _hasSentArrivalMessage = false;

      // 위치 추적 타이머 시작
      await registerHomeGeofence();
      _startLocationTracking();

      // 백그라운드 모드 지원 기본값 활성화
      if (!isBackgroundEnabled.value) {
        isBackgroundEnabled.value = true;
        await _saveSettings();
        debugPrint('✅ 백그라운드 모드 자동 활성화됨');
      }

      // 백그라운드 서비스 초기화 및 시작
      try {
        // 1. 백그라운드 위치 서비스 시작 (포그라운드 서비스)
        await _backgroundLocationService.init(); // 확실한 초기화

        final bgServiceStarted =
            await _backgroundLocationService.startService();

        if (bgServiceStarted) {
          debugPrint('✅ 백그라운드 위치 서비스 시작 성공');
          isBackgroundServiceRunning.value = true;

          // 설정 전송
          await _backgroundLocationService.sendMessage('update_settings', {
            'update_interval': 10,
            'home_lat': homeLocation.latitude,
            'home_lng': homeLocation.longitude,
            'home_radius': homeRadiusMeters.value,
            'recipients': messageRecipientIds,
            'message': arrivalMessage.value,
          });
        } else {
          debugPrint('⚠️ 백그라운드 위치 서비스 시작 실패, 포그라운드 모드로만 동작합니다.');
        }

        // 2. 백그라운드 작업 서비스 등록 (주기적 위치 확인)
        await _backgroundTaskService.registerPeriodicLocationCheck(
          frequency: const Duration(minutes: 3),
        );

        debugPrint('✅ 백그라운드 작업 서비스 등록 완료');
      } catch (e) {
        debugPrint('⚠️ 백그라운드 서비스 시작 중 오류: $e');
        debugPrint('⚠️ 포그라운드 모드로만 추적합니다.');
      }

      debugPrint(
          '✅ 귀가 추적 시작: 집 위치=${homeLocation.name}, 수신자=${messageRecipientIds.join(", ")}');

      // 메시지 설정 (Get.snackbar는 UI에서 처리)
      lastEventMessage.value = '귀가 추적이 시작되었습니다';

      // 알림 메시지 표시 (UI에서 사용)
      try {
        Get.snackbar(
          '귀가 알림',
          '귀가 추적이 시작되었습니다. 집에 도착하면 알림이 전송됩니다.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.blue.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          borderRadius: 8,
        );
      } catch (e) {
        debugPrint('⚠️ 스낵바 표시 오류 (무시됨): $e');
      }

      return true;
    } catch (e) {
      debugPrint('❌ 귀가 추적 시작 오류: $e');
      lastEventMessage.value = '귀가 추적 시작 오류: $e';
      return false;
    }
  }

  // 위치 추적 타이머 시작
  void _startLocationTracking() {
    // 이미 실행 중인 타이머가 있다면 취소
    _locationTrackingTimer?.cancel();

    // 즉시 현재 위치 확인
    _checkCurrentLocation();

    // 위치 추적 타이머 시작 (주기적으로 현재 위치 확인)
    _locationTrackingTimer = Timer.periodic(
        Duration(seconds: _trackingIntervalSeconds),
        (_) => _checkCurrentLocation());

    debugPrint('✅ 위치 추적 타이머 시작: ${_trackingIntervalSeconds}초 간격');
  }

  // 현재 위치 확인 및 집과의 거리 계산
  Future<void> _checkCurrentLocation() async {
    if (!isTrackingEnabled.value) {
      debugPrint('⚠️ 추적이 비활성화되어 위치 확인을 건너뜁니다.');
      return;
    }

    try {
      // 집 위치 정보 가져오기
      final homeLocation = _homeLocationService?.getSelectedHomeLocation();
      if (homeLocation == null) {
        debugPrint('❌ 선택된 집 위치 정보가 없어 위치 확인을 건너뜁니다.');
        return;
      }

      // 현재 위치 가져오기
      final locationService = Get.find<LocationService>();
      LatLng? currentLocation = locationService.currentLocation.value;

      // 현재 위치가 null이면 직접 위치 가져오기 시도
      if (currentLocation == null) {
        debugPrint('⚠️ 현재 위치가 null입니다. 직접 위치 가져오기 시도...');

        try {
          // Geolocator로 직접 위치 가져오기
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );

          // 가져온 위치로 업데이트
          currentLocation = LatLng(position.latitude, position.longitude);

          // LocationService에도 업데이트
          locationService.currentLocation.value = currentLocation;

          debugPrint(
              '✅ 직접 위치 가져오기 성공: ${position.latitude}, ${position.longitude}');
        } catch (e) {
          debugPrint('❌ 직접 위치 가져오기 실패: $e');
          return;
        }
      }

      if (currentLocation == null) {
        debugPrint('⚠️ 현재 위치를 가져올 수 없어 위치 확인을 건너뜁니다.');
        return;
      }

      // 집과의 거리 계산 (미터 단위)
      final distance = await _calculateDistance(
          currentLocation.latitude,
          currentLocation.longitude,
          homeLocation.latitude,
          homeLocation.longitude);

      _distanceToHome.value = distance;

      debugPrint(
          '📍 [HomeArrivalService] _checkCurrentLocation() 현재 위치: latitude=${currentLocation.latitude}, longitude=${currentLocation.longitude}');
      debugPrint(
          '🏠 [HomeArrivalService] _checkCurrentLocation() 집 위치: latitude=${homeLocation.latitude}, longitude=${homeLocation.longitude}');
      debugPrint(
          '📏 [HomeArrivalService] _checkCurrentLocation() 집과의 거리: ${distance.toStringAsFixed(2)}m (반경: ${homeRadiusMeters.value}m)');

      // 거리 정보 UI에 표시
      lastEventMessage.value = '집과의 거리: ${distance.toStringAsFixed(0)}m';

      // 변수 추가: 현재 집 반경 내에 있는지 여부와 이전에 밖에 있었는지 여부
      bool isInsideHomeRadius = distance <= homeRadiusMeters.value;
      bool shouldSendNotification =
          isInsideHomeRadius && !_hasSentArrivalMessage;

      // 집 반경 내에 있고 아직 알림을 보내지 않았다면 알림 트리거
      if (shouldSendNotification) {
        debugPrint(
            '🏠 [HomeArrivalService] 집 반경(${homeRadiusMeters.value}m) 내 진입 감지, 알림 트리거');
        await _triggerHomeArrival();
      } else if (isInsideHomeRadius) {
        debugPrint('🏠 [HomeArrivalService] 집 반경 내에 있지만 이미 알림을 보냈습니다.');
      } else {
        // 집 반경 밖에 있으면 알림 상태 초기화 (다시 들어올 때 알림 가능하도록)
        if (_hasSentArrivalMessage) {
          _hasSentArrivalMessage = false;
          debugPrint('🔄 [HomeArrivalService] 집 반경 밖으로 나감, 알림 상태 초기화');
        }
      }
    } catch (e) {
      debugPrint('❌ 위치 확인 중 오류: $e');
    }
  }

  // 두 좌표 사이의 거리 계산 (미터 단위)
  Future<double> _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) async {
    try {
      // 기본 거리 계산 메서드 사용
      return await Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    } catch (e) {
      debugPrint('❌ 거리 계산 오류: $e');
      return double.maxFinite; // 오류 시 매우 큰 값 반환 (알림 방지)
    }
  }

  // 테스트용: 집 도착 이벤트 수동 트리거
  Future<bool> testHomeArrival() async {
    try {
      debugPrint('🔍 테스트: 집 도착 이벤트 수동 트리거');

      // 이미 알림을 보냈다면 초기화
      _hasSentArrivalMessage = false;

      // 집 위치 정보 확인
      final homeLocation = _homeLocationService?.getSelectedHomeLocation();
      if (homeLocation == null) {
        debugPrint('❌ 테스트 실패: 선택된 집 위치가 없습니다.');
        return false;
      }

      // 알림 수신자 확인
      if (messageRecipientIds.isEmpty) {
        debugPrint('❌ 테스트 실패: 알림 수신자가 설정되지 않았습니다.');
        return false;
      }

      // 집 도착 트리거 호출
      await _triggerHomeArrival();

      debugPrint('✅ 테스트: 집 도착 이벤트 트리거 성공');
      return true;
    } catch (e) {
      debugPrint('❌ 테스트: 집 도착 이벤트 트리거 실패: $e');
      return false;
    }
  }

  // 서비스 종료 시 정리
  @override
  void onClose() {
    // 타이머 정리
    _locationTrackingTimer?.cancel();
    _locationTrackingTimer = null;

    debugPrint('✅ HomeArrivalService 종료 및 리소스 정리 완료');
    super.onClose();
  }
}
