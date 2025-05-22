import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/home_location_model.dart';
import '../models/emergency_contact_model.dart';
import 'home_location_service.dart';
import 'message_service.dart';
import 'location_service.dart';
import 'emergency_contact_service.dart';

class HomeArrivalService extends GetxController {
  // 싱글톤 인스턴스
  static HomeArrivalService? _instance;

  // 홈 위치 서비스
  late final HomeLocationService _homeLocationService;

  // 메시지 서비스
  late final MessageService _messageService;

  // 위치 서비스
  late final LocationService _locationService;

  // 비상 연락처 서비스
  late final EmergencyContactService _emergencyContactService;

  // 백그라운드 위치 트래킹 활성화 상태
  final RxBool isTrackingEnabled = false.obs;

  // 백그라운드 Isolate와 통신하기 위한 포트
  ReceivePort? _receivePort;

  // 위치 업데이트 구독
  StreamSubscription<Position>? _positionStreamSubscription;

  // 설정 값들
  final RxInt homeRadiusMeters = 50.obs; // 집 근처로 간주할 반경(미터)
  final RxString arrivalMessage = '집에 안전하게 도착했습니다.'.obs; // 기본 메시지

  // 현재 추적 중인 집 위치
  Rx<HomeLocationModel?> targetHomeLocation = Rx<HomeLocationModel?>(null);

  // 메시지를 보낼 대상 ID 목록
  final RxList<String> messageRecipientIds = <String>[].obs;

  // 추적 상태 (백그라운드 서비스 표시용)
  final RxBool isArrivingHome = false.obs; // 집으로 귀가 중인지 여부
  final RxString trackingStatus = '추적 비활성화'.obs; // 추적 상태 메시지

  // 포그라운드 서비스 ID
  static const String FOREGROUND_SERVICE_ID = 'home_arrival_tracking';

  // 알림 채널 ID
  static const String NOTIFICATION_CHANNEL_ID = 'home_arrival_notification';

  // SharedPreferences 키
  static const String PREF_TRACKING_ENABLED = 'home_arrival_tracking_enabled';
  static const String PREF_HOME_RADIUS = 'home_arrival_radius';
  static const String PREF_ARRIVAL_MESSAGE = 'home_arrival_message';
  static const String PREF_RECIPIENT_IDS = 'home_arrival_recipient_ids';

  // 백그라운드 Isolate와 통신을 위한 포트 이름
  static const String BACKGROUND_PORT_NAME = 'home_arrival_background_port';

  // 포그라운드 서비스
  late final FlutterBackgroundService _backgroundService;

  // 알림 플러그인
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // 싱글톤 인스턴스 가져오기
  static Future<HomeArrivalService> getInstance() async {
    if (_instance == null) {
      _instance = HomeArrivalService._();
      await _instance!._init();
    }
    return _instance!;
  }

  // 생성자 (private)
  HomeArrivalService._() {
    _backgroundService = FlutterBackgroundService();
  }

  // 초기화
  Future<void> _init() async {
    try {
      // 필요한 서비스들 가져오기
      _homeLocationService = await HomeLocationService.getInstance();
      _messageService = Get.find<MessageService>();
      _locationService = Get.find<LocationService>();
      _emergencyContactService = Get.find<EmergencyContactService>();

      // 알림 채널 초기화
      await _initNotifications();

      // 백그라운드 서비스 초기화
      await _initBackgroundService();

      // 저장된 설정 불러오기
      await _loadSettings();

      // 이전에 추적 중이었다면 재개
      if (isTrackingEnabled.value) {
        await startTracking();
      }

      debugPrint('✅ HomeArrivalService 초기화 완료');
    } catch (e) {
      debugPrint('❌ HomeArrivalService 초기화 오류: $e');
    }
  }

  // 알림 초기화
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

  // 백그라운드 서비스 초기화
  Future<void> _initBackgroundService() async {
    await _backgroundService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onBackgroundServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: NOTIFICATION_CHANNEL_ID,
        initialNotificationTitle: '귀가 알림',
        initialNotificationContent: '위치 추적 중...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onBackgroundServiceStart,
        onBackground: _onBackgroundServiceIOS,
      ),
    );

    // 백그라운드 서비스로부터 데이터 수신
    _backgroundService.on('update').listen((event) {
      if (event == null) return;

      // 추적 상태 업데이트
      if (event['status'] != null) {
        trackingStatus.value = event['status'];
        debugPrint('📱 백그라운드 서비스로부터 상태 업데이트: ${event['status']}');
      }

      // 집 도착 이벤트 처리
      if (event['arrived'] == true) {
        debugPrint('🏠 집 도착 이벤트 수신됨, 추적 중지');
        stopTracking();
      }
    });

    debugPrint('✅ 백그라운드 서비스 초기화 완료');
  }

  // 설정 불러오기
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 추적 활성화 상태
      isTrackingEnabled.value = prefs.getBool(PREF_TRACKING_ENABLED) ?? false;

      // 집 반경
      homeRadiusMeters.value = prefs.getInt(PREF_HOME_RADIUS) ?? 50;

      // 도착 메시지
      arrivalMessage.value =
          prefs.getString(PREF_ARRIVAL_MESSAGE) ?? '집에 안전하게 도착했습니다.';

      // 수신자 ID 목록
      final recipientIdsJson = prefs.getStringList(PREF_RECIPIENT_IDS) ?? [];
      messageRecipientIds.value = recipientIdsJson;

      debugPrint('✅ HomeArrivalService 설정 로드 완료');
    } catch (e) {
      debugPrint('❌ HomeArrivalService 설정 로드 오류: $e');
    }
  }

  // 설정 저장하기
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 추적 활성화 상태
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

  // 추적 시작
  Future<bool> startTracking() async {
    try {
      // 이미 추적 중이면 무시
      if (isTrackingEnabled.value) {
        debugPrint('⚠️ 이미 귀가 추적 중입니다.');
        return true;
      }

      // 선택된 집 위치 가져오기
      final homeLocation = _homeLocationService.getSelectedHomeLocation();
      if (homeLocation == null) {
        debugPrint('❌ 선택된 집 위치가 없습니다.');
        return false;
      }

      // 추적할 집 위치 설정
      targetHomeLocation.value = homeLocation;

      // 위치 권한 확인
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        debugPrint('❌ 위치 권한이 없어 귀가 추적을 시작할 수 없습니다.');
        return false;
      }

      // 수신자 목록 확인
      if (messageRecipientIds.isEmpty) {
        // 비상 연락처에서 첫 번째 연락처를 기본으로 설정
        final List<EmergencyContact> contacts =
            _emergencyContactService.contacts;
        if (contacts.isNotEmpty) {
          messageRecipientIds.add(contacts.first.id);
        }
      }

      // 백그라운드 서비스에 필요한 데이터 전달
      final Map<String, dynamic> data = {
        'homeLatitude': homeLocation.latitude,
        'homeLongitude': homeLocation.longitude,
        'homeRadius': homeRadiusMeters.value,
        'homeName': homeLocation.name,
        'arrivalMessage': arrivalMessage.value,
        'recipientIds': messageRecipientIds.toList(),
      };

      // 백그라운드 서비스 시작
      await _backgroundService.startService();

      // 데이터 전송
      _backgroundService.invoke('update', data);

      // 추적 상태 업데이트
      isTrackingEnabled.value = true;
      isArrivingHome.value = true;
      trackingStatus.value = '집 근처 감지 중...';

      // 설정 저장
      await _saveSettings();

      debugPrint(
          '✅ 귀가 추적 시작: ${homeLocation.name} (${homeLocation.latitude}, ${homeLocation.longitude})');
      return true;
    } catch (e) {
      debugPrint('❌ 귀가 추적 시작 오류: $e');
      return false;
    }
  }

  // 추적 중지
  Future<void> stopTracking() async {
    try {
      // 먼저 현재 상태 확인 (알림 표시 조건용)
      final wasTracking = isTrackingEnabled.value;

      // 백그라운드 서비스 중지
      _backgroundService.invoke('stopService', {});

      // 추적 상태 업데이트
      isTrackingEnabled.value = false;
      isArrivingHome.value = false;
      trackingStatus.value = '추적 비활성화';

      // 완료 알림 표시 (추적이 실제로 활성화되어 있었을 때만)
      if (wasTracking) {
        await _showHomeArrivalCompletionNotification();
      }

      // 설정 저장
      await _saveSettings();

      debugPrint('✅ 귀가 추적 중지');
    } catch (e) {
      debugPrint('❌ 귀가 추적 중지 오류: $e');
    }
  }

  // 귀가 알림 완료 알림 표시
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

      // 백그라운드 위치 권한 확인 (Android 10 이상에서 필요)
      if (permission == LocationPermission.whileInUse) {
        // 백그라운드 권한 요청
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always) {
          debugPrint('⚠️ 백그라운드 위치 권한이 없습니다. 앱이 백그라운드일 때 추적이 중단될 수 있습니다.');
          // 일단 허용 (iOS에서는 whileInUse가 최대)
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ 위치 권한 확인 오류: $e');
      return false;
    }
  }

  // 백그라운드 서비스 시작 핸들러 (Android)
  @pragma('vm:entry-point')
  static void _onBackgroundServiceStart(ServiceInstance service) async {
    // SharedPreferences 인스턴스
    final prefs = await SharedPreferences.getInstance();

    // Isolate와 통신하기 위한 포트 등록
    DartPluginRegistrant.ensureInitialized();

    debugPrint('🚀 백그라운드 서비스 시작됨');

    // 백그라운드 모드 확인
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
        debugPrint('🟢 백그라운드 서비스: 포그라운드 모드로 설정됨');
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
        debugPrint('🔴 백그라운드 서비스: 백그라운드 모드로 설정됨');
      });
    }

    // 홈 위치 정보
    double? homeLatitude;
    double? homeLongitude;
    int homeRadius = 50;
    String homeName = '집';
    String arrivalMessage = '집에 안전하게 도착했습니다.';
    List<String> recipientIds = [];
    bool messageAlreadySent = false;

    // 위치 업데이트 스트림
    StreamSubscription<Position>? positionStream;

    // 도착 알림 전송 함수
    Future<void> _sendArrivalNotification() async {
      try {
        // 도착 메시지 저장
        await prefs.setString('arrival_notification_message', arrivalMessage);

        // 수신자 ID 목록 저장
        await prefs.setStringList(
            'arrival_notification_recipients', recipientIds);

        // 알림 발송 요청 플래그 설정 (메인 앱에서 처리)
        await prefs.setBool('arrival_notification_pending', true);

        // 알림 정보 업데이트
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '집에 도착했습니다',
            content: '귀가 알림을 전송했습니다.',
          );
        }

        // 로컬 알림 표시 (백그라운드에서도 가능하도록)
        // 백그라운드에서 전송할 알림 준비
        final FlutterLocalNotificationsPlugin notificationsPlugin =
            FlutterLocalNotificationsPlugin();

        // Android 알림 채널 설정
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
          'home_arrival_channel',
          '귀가 알림',
          channelDescription: '귀가 알림 서비스 알림',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        );

        // 알림 상세 정보
        const NotificationDetails platformDetails = NotificationDetails(
          android: androidDetails,
        );

        // 알림 표시
        await notificationsPlugin.show(
          1, // 알림 ID
          '집에 도착했습니다',
          arrivalMessage,
          platformDetails,
        );
      } catch (e) {
        debugPrint('❌ 백그라운드 서비스 도착 알림 처리 오류: $e');
      }
    }

    // 위치 추적 시작 함수
    void _startLocationTracking() {
      // 기존 구독 취소
      positionStream?.cancel();

      // 새 위치 구독 시작
      final locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '귀가 알림',
          notificationText: '위치 추적 중...',
          enableWakeLock: true,
        ),
      );

      positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        // 집 위치가 설정되지 않았으면 무시
        if (homeLatitude == null || homeLongitude == null) return;

        // 현재 위치와 집 위치 사이의 거리 계산
        double distanceInMeters = Geolocator.distanceBetween(position.latitude,
            position.longitude, homeLatitude!, homeLongitude!);

        // 상태 업데이트
        final statusText =
            '${homeName}까지 ${distanceInMeters.toStringAsFixed(0)}m 남음';

        // 알림 업데이트
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '귀가 알림',
            content: statusText,
          );
        }

        // 메인 앱에 상태 업데이트 전송
        service.invoke('update', {'status': statusText});

        // 집 근처에 도착했는지 확인
        if (distanceInMeters <= homeRadius && !messageAlreadySent) {
          // 도착 알림 보내기
          _sendArrivalNotification();

          // 중복 전송 방지
          messageAlreadySent = true;

          // 메인 앱에 도착 알림 전송
          service.invoke('update', {'arrived': true});
        }
      });
    }

    // 데이터 업데이트 수신 리스너
    service.on('update').listen((event) {
      // 무시 가능한 이벤트
      if (event == null) return;

      debugPrint('📥 백그라운드 서비스: 데이터 업데이트 수신: $event');

      if (event['homeLatitude'] != null && event['homeLongitude'] != null) {
        homeLatitude = event['homeLatitude'];
        homeLongitude = event['homeLongitude'];
        homeRadius = event['homeRadius'] ?? 50;
        homeName = event['homeName'] ?? '집';
        arrivalMessage = event['arrivalMessage'] ?? '집에 안전하게 도착했습니다.';

        if (event['recipientIds'] != null) {
          recipientIds = List<String>.from(event['recipientIds']);
        }

        // 알림 업데이트
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '귀가 알림',
            content: '$homeName까지 추적 중...',
          );
        }

        // 위치 추적 시작
        _startLocationTracking();
      }
    });

    // 상태 요청 리스너
    service.on('getStatus').listen((event) {
      final statusText = positionStream != null ? '추적 중...' : '초기화 중...';

      debugPrint('📤 백그라운드 서비스: 상태 업데이트 전송: $statusText');
      service.invoke('update', {'status': statusText});
    });

    // 서비스 종료 명령 리스너
    service.on('stopService').listen((event) {
      // 위치 업데이트 중지
      positionStream?.cancel();

      debugPrint('🛑 백그라운드 서비스: 종료 요청 수신');

      // 서비스 종료
      service.stopSelf();
    });
  }

  // iOS 백그라운드 핸들러 (iOS)
  @pragma('vm:entry-point')
  static bool _onBackgroundServiceIOS(ServiceInstance service) {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // iOS에서는 백그라운드 작업이 제한적이므로 주기적인 작업만 수행
    return true;
  }

  // 메시지 수신자 설정
  Future<void> setMessageRecipients(List<String> recipientIds) async {
    messageRecipientIds.value = recipientIds;
    await _saveSettings();

    // 현재 추적 중이면 백그라운드 서비스에 업데이트
    if (isTrackingEnabled.value) {
      _backgroundService.invoke('update', {
        'recipientIds': recipientIds,
      });
    }
  }

  // 도착 메시지 설정
  Future<void> setArrivalMessage(String message) async {
    arrivalMessage.value = message;
    await _saveSettings();

    // 현재 추적 중이면 백그라운드 서비스에 업데이트
    if (isTrackingEnabled.value) {
      _backgroundService.invoke('update', {
        'arrivalMessage': message,
      });
    }
  }

  // 집 반경 설정
  Future<void> setHomeRadius(int radiusMeters) async {
    homeRadiusMeters.value = radiusMeters;
    await _saveSettings();

    // 현재 추적 중이면 백그라운드 서비스에 업데이트
    if (isTrackingEnabled.value) {
      _backgroundService.invoke('update', {
        'homeRadius': radiusMeters,
      });
    }
  }

  // 앱 재시작 시 도착 알림 확인 및 처리
  Future<void> checkPendingArrivalNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isPending =
          prefs.getBool('arrival_notification_pending') ?? false;

      if (isPending) {
        // 저장된 알림 데이터 불러오기
        final message = prefs.getString('arrival_notification_message') ??
            '집에 안전하게 도착했습니다.';
        final recipientIds =
            prefs.getStringList('arrival_notification_recipients') ?? [];

        // 메시지 전송
        for (String recipientId in recipientIds) {
          await _messageService.sendMessage(
            receiverId: recipientId,
            content: message,
          );
          debugPrint('✅ 지연된 귀가 알림 전송 완료: $recipientId');
        }

        // 로컬 알림 표시
        await _showHomeArrivalNotification(message);

        // 알림 플래그 초기화
        await prefs.setBool('arrival_notification_pending', false);
      }
    } catch (e) {
      debugPrint('❌ 지연된 귀가 알림 처리 오류: $e');
    }
  }

  // 귀가 알림 로컬 알림 표시
  Future<void> _showHomeArrivalNotification(String message) async {
    try {
      // Android 알림 세부 정보
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'home_arrival_channel',
        '귀가 알림',
        channelDescription: '귀가 알림 서비스 알림',
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
        0, // 알림 ID
        '귀가 알림',
        message,
        platformDetails,
      );

      debugPrint('✅ 귀가 알림 표시 완료');
    } catch (e) {
      debugPrint('❌ 귀가 알림 표시 오류: $e');
    }
  }

  // 추적 상태 리프레시 (앱이 포그라운드로 돌아올 때 호출)
  Future<void> refreshTrackingStatus() async {
    try {
      debugPrint('🔄 HomeArrivalService: 추적 상태 리프레시 중');

      // 현재 서비스 실행 상태 확인
      final isRunning = await _backgroundService.isRunning();

      // SharedPreferences에서 저장된 설정 확인
      final prefs = await SharedPreferences.getInstance();
      final savedIsTracking = prefs.getBool(PREF_TRACKING_ENABLED) ?? false;

      // 상태 불일치 확인 및 수정
      if (isRunning != isTrackingEnabled.value) {
        debugPrint(
            '⚠️ 추적 상태 불일치 감지: UI=${isTrackingEnabled.value}, 서비스=$isRunning');
        isTrackingEnabled.value = isRunning;
      }

      if (savedIsTracking != isTrackingEnabled.value) {
        debugPrint(
            '⚠️ 저장된 추적 상태 불일치 감지: UI=${isTrackingEnabled.value}, 저장됨=$savedIsTracking');
        await _saveSettings();
      }

      // 알림 확인
      await checkPendingArrivalNotification();

      // 백그라운드 서비스가 실행 중이면 상태 업데이트 요청
      if (isRunning) {
        debugPrint('✅ 추적 중인 백그라운드 서비스 발견, 상태 업데이트 요청');
        isArrivingHome.value = true;
        _backgroundService.invoke('getStatus', {});
      } else if (isTrackingEnabled.value) {
        debugPrint('⚠️ 추적 설정은 활성화되어 있으나 서비스가 실행 중이지 않음, 상태 수정');
        isTrackingEnabled.value = false;
        isArrivingHome.value = false;
        trackingStatus.value = '추적 비활성화';
        await _saveSettings();
      }

      debugPrint('✅ 추적 상태 리프레시 완료: 추적 중=${isTrackingEnabled.value}');
    } catch (e) {
      debugPrint('❌ 추적 상태 리프레시 오류: $e');
    }
  }

  @override
  void onClose() {
    // 리소스 정리
    _positionStreamSubscription?.cancel();
    _receivePort?.close();
    super.onClose();
  }
}
