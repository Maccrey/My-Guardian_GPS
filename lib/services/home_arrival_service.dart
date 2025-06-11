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
import 'package:watch_over/services/home_location_service.dart';
import 'package:watch_over/services/geofence_service.dart';

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

  // 추적 상태 변수
  bool _hasSentArrivalMessage = false;

  // 초기화
  Future<void> _init() async {
    try {
      // 서비스 인스턴스 가져오기
      _locationService = Get.find<LocationService>();
      _authService = Get.find<AuthService>();
      _messageService = Get.find<MessageService>();
      // EmergencyContactService 안전하게 등록 및 초기화
      if (!Get.isRegistered<EmergencyContactService>()) {
        Get.put(EmergencyContactService(), permanent: true);
      }
      _emergencyContactService = Get.find<EmergencyContactService>();
      _homeLocationService = await HomeLocationService.getInstance();
      _geofenceService = Get.put(GeofenceService());
      // 지오펜스 이벤트 핸들러 등록
      _geofenceService.setEventHandler(_onGeofenceEvent);

      // 알림 초기화 (임시로 주석 처리)
      // await _initNotifications();

      // 저장된 설정 로드
      await _loadSettings();

      debugPrint('✅ HomeArrivalService 초기화 성공');
    } catch (e, stack) {
      debugPrint('❌ HomeArrivalService 초기화 오류: $e\n$stack');
      lastEventMessage.value = '귀가알림 서비스 초기화 오류: $e';
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
  Future<bool> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 알림 메시지 저장
      await prefs.setString(PREF_ARRIVAL_MESSAGE, arrivalMessage.value);

      // 메시지 수신자 저장
      await prefs.setStringList(PREF_RECIPIENT_IDS, messageRecipientIds);

      // 집 반경 저장
      await prefs.setInt(PREF_HOME_RADIUS, homeRadiusMeters.value);

      // 추적 활성화 상태 저장
      await prefs.setBool(PREF_TRACKING_ENABLED, isTrackingEnabled.value);

      debugPrint('✅ 모든 설정이 저장되었습니다.');
      return true;
    } catch (e) {
      debugPrint('❌ 설정 저장 중 오류가 발생했습니다: $e');
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

  // 집 위치 등록 시 지오펜스 등록
  Future<void> registerHomeGeofence() async {
    final homeLocation = _homeLocationService?.getSelectedHomeLocation();
    if (homeLocation == null) return;
    await _geofenceService.registerGeofence(
      id: 'home',
      latitude: homeLocation.latitude,
      longitude: homeLocation.longitude,
      radius: homeRadiusMeters.value.toDouble(),
    );
    debugPrint('🏠 집 위치 지오펜스 등록 완료');
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
    final homeLocation = _homeLocationService!.getSelectedHomeLocation();
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

            final success = await _homeLocationService!.sendHomeArrivalMessage(
              receiverId: contact.userId!,
              message: arrivalMessage.value,
              homeLocation: homeLocation,
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
          final success = await _homeLocationService!.sendHomeArrivalMessage(
            receiverId: recipientId,
            message: arrivalMessage.value,
            homeLocation: homeLocation,
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

  // 추적 시작 (포그라운드 위치 추적 포함)
  @override
  Future<bool> startTracking() async {
    try {
      if (isTrackingEnabled.value) {
        debugPrint('⚠️ 이미 귀가 추적 중입니다.');
        return true;
      }

      // HomeLocationService 초기화 확인 및 재시도
      if (_homeLocationService == null) {
        debugPrint('🔄 HomeLocationService 초기화 시도 중...');
        try {
          _homeLocationService = await HomeLocationService.getInstance();
          debugPrint('✅ HomeLocationService 초기화 성공');
        } catch (e) {
          debugPrint('❌ HomeLocationService 초기화 실패: $e');
          lastEventMessage.value = 'HomeLocationService 초기화 실패: $e';
          return false;
        }
      }

      // 집 위치 확인
      final homeLocation = _homeLocationService!.getSelectedHomeLocation();
      if (homeLocation == null) {
        debugPrint('❌ 선택된 집 위치가 없습니다.');
        lastEventMessage.value = '선택된 집 위치가 없습니다. 먼저 집 위치를 등록해주세요.';
        return false;
      }

      // 위치 권한 확인
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        debugPrint('❌ 위치 권한이 없어 귀가 추적을 시작할 수 없습니다.');
        lastEventMessage.value = '위치 권한이 없어 귀가 추적을 시작할 수 없습니다.';
        return false;
      }

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
      await _saveSettings();
      _hasSentArrivalMessage = false;

      // 위치 추적 타이머 시작
      await registerHomeGeofence();

      debugPrint(
          '✅ 귀가 추적(포그라운드) 시작: 집 위치=${homeLocation.name}, 수신자=${messageRecipientIds.join(", ")}');

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

  // 추적 중지 (포그라운드 위치 추적 중지)
  @override
  Future<void> stopTracking() async {
    if (!isTrackingEnabled.value) {
      debugPrint('⚠️ 이미 귀가 추적이 중지되어 있습니다.');
      return;
    }

    isTrackingEnabled.value = false;
    isArrivingHome.value = false;
    trackingStatus.value = '추적 중지됨';
    _hasSentArrivalMessage = false; // 메시지 전송 상태 초기화
    await _saveSettings();

    debugPrint('✅ 귀가 추적 중지됨');

    // 추적 중지 알림 (UI에서 처리)
    try {
      Get.snackbar(
        '귀가 알림',
        '귀가 추적이 중지되었습니다.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        borderRadius: 8,
        icon: const Icon(Icons.pause_circle_filled, color: Colors.white),
      );
    } catch (e) {
      debugPrint('⚠️ 스낵바 표시 오류 (무시됨): $e');
    }
  }

  // 서비스 종료 시 정리
  @override
  void onClose() {
    super.onClose();
  }
}
