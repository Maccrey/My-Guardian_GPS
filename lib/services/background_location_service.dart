import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watch_over/services/home_location_service.dart';
import 'package:watch_over/services/notification_service.dart';
import 'package:watch_over/services/home_arrival_service.dart';

/// 백그라운드 위치 추적 서비스
/// 앱이 백그라운드에 있을 때도 위치 추적 및 귀가 알림 기능을 제공합니다.
class BackgroundLocationService {
  static const String _serviceName = 'home_arrival_background_service';
  static const String _channelId = 'home_arrival_foreground_channel';
  static const String _channelName = '귀가 알림 서비스';
  static const int _notificationId = 888;

  // 싱글톤 인스턴스
  static BackgroundLocationService? _instance;
  static BackgroundLocationService get instance =>
      _instance ??= BackgroundLocationService._();

  // 백그라운드 서비스 인스턴스
  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _isServiceInitialized = false;

  // 백그라운드 서비스 상태
  final RxBool isRunning = false.obs;

  // 생성자
  BackgroundLocationService._();

  /// 백그라운드 서비스 초기화
  Future<void> init() async {
    if (_isServiceInitialized) return;

    // 알림 서비스 초기화
    final notificationService = await NotificationService.getInstance();
    await notificationService.setupLocalNotifications();

    // 백그라운드 서비스 설정
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        // 포그라운드 서비스 설정
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: '귀가 알림',
        initialNotificationContent: '위치 추적 중...',
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );

    // 서비스 상태 리스너 등록
    _service.on('location_update').listen((event) {
      if (event != null) {
        debugPrint('📍 백그라운드 위치 업데이트: $event');
      }
    });

    _service.on('home_arrival_event').listen((event) {
      if (event != null && event['arrived'] == true) {
        debugPrint('🏠 귀가 이벤트 감지: $event');
        _showHomeArrivalNotification(event['message'] ?? '집에 안전하게 도착했습니다.');
      }
    });

    _isServiceInitialized = true;
    isRunning.value = await _service.isRunning();

    debugPrint('✅ 백그라운드 위치 추적 서비스 초기화 완료: 실행 중=${isRunning.value}');
  }

  /// 백그라운드 서비스 시작
  Future<bool> startService() async {
    if (!_isServiceInitialized) {
      await init();
    }

    if (await _service.isRunning()) {
      debugPrint('⚠️ 백그라운드 서비스가 이미 실행 중입니다.');
      return true;
    }

    // 위치 권한 확인
    final permission = await _checkLocationPermission();
    if (!permission) {
      debugPrint('❌ 위치 권한이 없어 백그라운드 서비스를 시작할 수 없습니다.');
      return false;
    }

    // 서비스 시작
    await _service.startService();

    // 상태 확인
    isRunning.value = await _service.isRunning();
    debugPrint('✅ 백그라운드 위치 추적 서비스 시작: ${isRunning.value}');

    return isRunning.value;
  }

  /// 백그라운드 서비스 중지
  Future<bool> stopService() async {
    if (!_isServiceInitialized || !(await _service.isRunning())) {
      debugPrint('⚠️ 백그라운드 서비스가 실행 중이지 않습니다.');
      isRunning.value = false;
      return true;
    }

    // 서비스 중지
    _service.invoke('stopService');

    // 상태 확인
    isRunning.value = await _service.isRunning();
    debugPrint('✅ 백그라운드 위치 추적 서비스 중지: ${isRunning.value}');

    return !isRunning.value;
  }

  /// 백그라운드 서비스에 메시지 전송
  Future<void> sendMessage(String code, Map<String, dynamic> data) async {
    if (!_isServiceInitialized || !(await _service.isRunning())) {
      debugPrint('⚠️ 백그라운드 서비스가 실행 중이지 않아 메시지를 전송할 수 없습니다: $code');
      return;
    }

    _service.invoke(code, data);
    debugPrint('📤 백그라운드 서비스에 메시지 전송: $code, $data');
  }

  /// 위치 권한 확인
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

      // 백그라운드 위치 권한 확인 (Android 10 이상)
      if (permission == LocationPermission.whileInUse) {
        debugPrint('⚠️ 앱 사용 중에만 위치 권한이 있습니다. 백그라운드 권한 요청...');
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('❌ 위치 권한 확인 오류: $e');
      return false;
    }
  }

  /// 귀가 알림 표시
  Future<void> _showHomeArrivalNotification(String message) async {
    try {
      final notificationService = await NotificationService.getInstance();
      await notificationService.showNotification(
        id: 999,
        title: '🏠 귀가 알림',
        body: message,
        payload: 'home_arrival',
      );
      debugPrint('✅ 귀가 알림 표시 완료');
    } catch (e) {
      debugPrint('❌ 귀가 알림 표시 오류: $e');
    }
  }
}

/// iOS 백그라운드 서비스 핸들러 (메인 스레드에서 호출됨)
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  debugPrint('🍏 iOS 백그라운드 서비스 시작');

  // SharedPreferences 인스턴스 생성
  final prefs = await SharedPreferences.getInstance();

  // 위치 추적 활성화 상태 확인
  final isTrackingEnabled =
      prefs.getBool('home_arrival_tracking_enabled') ?? false;

  debugPrint('🍏 iOS 백그라운드 서비스 상태: 추적 활성화=$isTrackingEnabled');

  return isTrackingEnabled;
}

/// 백그라운드 서비스 메인 함수 (별도 격리 환경에서 실행됨)
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // 디버그 로그
  debugPrint('🚀 백그라운드 위치 추적 서비스 시작');

  // 포그라운드 서비스로 설정
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }

  // 위치 추적 설정
  final locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10, // 10미터 이상 이동 시 업데이트
    timeLimit: const Duration(seconds: 30), // 최대 30초마다 업데이트
  );

  // SharedPreferences 인스턴스 생성
  final prefs = await SharedPreferences.getInstance();

  // 중요 설정값 로드
  int homeRadius = prefs.getInt('home_arrival_radius') ?? 50;
  String arrivalMessage =
      prefs.getString('home_arrival_message') ?? '집에 안전하게 도착했습니다.';
  List<String> recipientIds =
      prefs.getStringList('home_arrival_recipient_ids') ?? [];
  String selectedHomeLocationId =
      prefs.getString('selected_home_location_id') ?? '';
  String homeLocationsJson = prefs.getString('home_locations') ?? '[]';

  debugPrint('📊 설정 로드 완료: 반경=${homeRadius}m, 수신자=${recipientIds.length}명');

  // 홈 위치 정보 가져오기 (필요한 코드 추가)
  double? homeLat;
  double? homeLng;

  // TODO: JSON 파싱으로 homeLat, homeLng 설정

  // 위치 스트림 구독
  final positionStream =
      Geolocator.getPositionStream(locationSettings: locationSettings);

  // 마지막으로 알림을 보낸 시간 (중복 알림 방지)
  DateTime? lastNotificationTime;
  bool hasSentArrivalNotification = false;

  positionStream.listen((Position position) async {
    // 최신 위치 정보 업데이트
    debugPrint('📍 현재 위치: ${position.latitude}, ${position.longitude}');

    // 서비스 상태 업데이트
    service.invoke('location_update', {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // 위치 추적 활성화 상태 확인
    final isTrackingEnabled =
        prefs.getBool('home_arrival_tracking_enabled') ?? false;
    if (!isTrackingEnabled) {
      debugPrint('⚠️ 위치 추적이 비활성화되어 있습니다.');
      return;
    }

    // 집 위치가 설정되었는지 확인
    if (homeLat == null || homeLng == null) {
      debugPrint('⚠️ 집 위치가 설정되지 않았습니다.');
      return;
    }

    // 집과의 거리 계산
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      homeLat!,
      homeLng!,
    );

    debugPrint(
        '📏 집과의 거리: ${distance.toStringAsFixed(2)}m (설정 반경: ${homeRadius}m)');

    // 알림 전송 조건 확인 (집 반경 내 진입 + 중복 알림 방지)
    if (distance <= homeRadius && !hasSentArrivalNotification) {
      // 마지막 알림과 10분 이상 차이가 나는지 확인
      final now = DateTime.now();
      if (lastNotificationTime == null ||
          now.difference(lastNotificationTime!).inMinutes >= 10) {
        debugPrint('🏠 집 도착 감지! 알림 전송 중...');

        // 알림 상태 업데이트
        hasSentArrivalNotification = true;
        lastNotificationTime = now;

        // 귀가 알림 이벤트 발생
        service.invoke('home_arrival_event', {
          'arrived': true,
          'message': arrivalMessage,
          'timestamp': now.millisecondsSinceEpoch,
        });

        // 집 도착 정보 저장 (앱이 다시 시작할 때 처리)
        await prefs.setBool('arrival_notification_pending', true);
        await prefs.setString('arrival_notification_message', arrivalMessage);
        await prefs.setStringList(
            'arrival_notification_recipients', recipientIds);

        // 알림 표시 (포그라운드 서비스)
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '🏠 집에 도착했습니다',
            content: arrivalMessage,
          );
        }

        debugPrint('✅ 귀가 알림 전송 완료');

        // 추적 자동 중지 설정 (3초 후)
        await Future.delayed(const Duration(seconds: 3));

        // 추적 중지 설정 저장
        await prefs.setBool('home_arrival_tracking_enabled', false);

        // 자동 종료 알림 업데이트
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: '귀가 추적 완료',
            content: '집에 도착하여 추적이 자동으로 중지되었습니다.',
          );
        }

        // 3초 후 서비스 중지 (필요한 처리가 완료될 수 있도록)
        await Future.delayed(const Duration(seconds: 3));
        service.stopSelf(); // 서비스 종료
        debugPrint('✅ 귀가 알림 전송 후 백그라운드 서비스 자동 종료');
      }
    } else if (distance > homeRadius) {
      // 집 반경을 벗어나면 알림 상태 초기화
      hasSentArrivalNotification = false;
    }
  });

  // 서비스 중지 메시지 처리
  service.on('stopService').listen((event) async {
    debugPrint('🛑 백그라운드 서비스 중지 요청');
    service.stopSelf();
  });
}
