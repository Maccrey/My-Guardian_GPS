import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:watch_over/services/notification_service.dart';
import 'package:watch_over/services/home_arrival_service.dart';
import 'package:watch_over/services/home_location_service.dart';

/// 백그라운드 작업 서비스
/// Workmanager를 사용하여 백그라운드 작업을 관리합니다.
class BackgroundTaskService {
  // 작업 식별자
  static const String periodicLocationCheckTask = 'periodicLocationCheck';
  static const String oneTimeLocationCheckTask = 'oneTimeLocationCheck';

  // 싱글톤 인스턴스
  static BackgroundTaskService? _instance;
  static BackgroundTaskService get instance =>
      _instance ??= BackgroundTaskService._();

  // 초기화 상태
  bool _isInitialized = false;

  // 생성자
  BackgroundTaskService._();

  /// 백그라운드 작업 서비스 초기화
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Workmanager 초기화
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: true, // 디버그 모드 활성화 (프로덕션에서는 false로 변경)
      );

      _isInitialized = true;
      debugPrint('✅ 백그라운드 작업 서비스 초기화 완료');
    } catch (e) {
      debugPrint('❌ 백그라운드 작업 서비스 초기화 오류: $e');
    }
  }

  /// 주기적 위치 체크 작업 등록
  Future<void> registerPeriodicLocationCheck({
    Duration frequency = const Duration(minutes: 15),
  }) async {
    if (!_isInitialized) {
      await init();
    }

    try {
      // 기존 작업 취소
      await Workmanager().cancelByUniqueName(periodicLocationCheckTask);

      // 위치 권한 확인
      final permission = await _checkLocationPermission();
      if (!permission) {
        debugPrint('❌ 위치 권한이 없어 백그라운드 작업을 등록할 수 없습니다.');
        return;
      }

      // 주기적 작업 등록 (최소 15분 간격)
      await Workmanager().registerPeriodicTask(
        periodicLocationCheckTask,
        periodicLocationCheckTask,
        frequency:
            frequency.inMinutes < 15 ? const Duration(minutes: 15) : frequency,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );

      debugPrint('✅ 주기적 위치 체크 작업 등록 완료 (${frequency.inMinutes}분 간격)');
    } catch (e) {
      debugPrint('❌ 주기적 위치 체크 작업 등록 오류: $e');
    }
  }

  /// 일회성 위치 체크 작업 등록
  Future<void> registerOneTimeLocationCheck({
    Duration initialDelay = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) {
      await init();
    }

    try {
      // 위치 권한 확인
      final permission = await _checkLocationPermission();
      if (!permission) {
        debugPrint('❌ 위치 권한이 없어 백그라운드 작업을 등록할 수 없습니다.');
        return;
      }

      // 일회성 작업 등록
      await Workmanager().registerOneOffTask(
        oneTimeLocationCheckTask,
        oneTimeLocationCheckTask,
        initialDelay: initialDelay,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      debugPrint('✅ 일회성 위치 체크 작업 등록 완료 (${initialDelay.inSeconds}초 후 실행)');
    } catch (e) {
      debugPrint('❌ 일회성 위치 체크 작업 등록 오류: $e');
    }
  }

  /// 백그라운드 작업 취소
  Future<void> cancelAllTasks() async {
    if (!_isInitialized) {
      await init();
    }

    try {
      await Workmanager().cancelAll();
      debugPrint('✅ 모든 백그라운드 작업 취소 완료');
    } catch (e) {
      debugPrint('❌ 백그라운드 작업 취소 오류: $e');
    }
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

      // 백그라운드 위치 권한 확인
      return permission == LocationPermission.always;
    } catch (e) {
      debugPrint('❌ 위치 권한 확인 오류: $e');
      return false;
    }
  }
}

/// 백그라운드 작업 콜백 함수
/// 별도의 격리된 환경에서 실행됩니다.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Flutter 바인딩 초기화
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    debugPrint('🚀 백그라운드 작업 시작: $taskName');

    try {
      // 작업 유형에 따라 처리
      switch (taskName) {
        case BackgroundTaskService.periodicLocationCheckTask:
        case BackgroundTaskService.oneTimeLocationCheckTask:
          await _handleLocationCheckTask();
          break;
        default:
          debugPrint('⚠️ 알 수 없는 작업: $taskName');
      }

      debugPrint('✅ 백그라운드 작업 완료: $taskName');
      return true;
    } catch (e) {
      debugPrint('❌ 백그라운드 작업 오류: $e');
      return false;
    }
  });
}

/// 위치 확인 작업 처리
Future<void> _handleLocationCheckTask() async {
  try {
    // SharedPreferences 인스턴스 생성
    final prefs = await SharedPreferences.getInstance();

    // 위치 추적 활성화 상태 확인
    final isTrackingEnabled =
        prefs.getBool('home_arrival_tracking_enabled') ?? false;
    if (!isTrackingEnabled) {
      debugPrint('⚠️ 위치 추적이 비활성화되어 있습니다.');
      return;
    }

    // 설정값 로드
    final homeRadius = prefs.getInt('home_arrival_radius') ?? 50;
    final arrivalMessage =
        prefs.getString('home_arrival_message') ?? '집에 안전하게 도착했습니다.';
    final recipientIds =
        prefs.getStringList('home_arrival_recipient_ids') ?? [];
    final selectedHomeLocationId =
        prefs.getString('selected_home_location_id') ?? '';

    // 선택된 홈 위치가 없으면 종료
    if (selectedHomeLocationId.isEmpty) {
      debugPrint('⚠️ 선택된 홈 위치가 없습니다.');
      return;
    }

    // 홈 위치 정보 로드 (홈 위치 서비스 없이 직접 구현)
    final homeLocationsJson = prefs.getString('home_locations') ?? '[]';

    // 홈 위치 정보 가져오기 (직접 저장된 값 및 JSON 파싱)
    double? homeLat;
    double? homeLng;

    // 1. 직접 저장된 값 확인 (가장 신뢰할 수 있는 소스)
    homeLat = prefs.getDouble('home_latitude');
    homeLng = prefs.getDouble('home_longitude');

    if (homeLat != null && homeLng != null) {
      debugPrint('🏠 직접 저장된 홈 위치 발견: lat=$homeLat, lng=$homeLng');
    } else {
      // 2. JSON 파싱으로 시도
      try {
        if (homeLocationsJson.isNotEmpty && homeLocationsJson != '[]') {
          final regExp = RegExp(
              r'"id":"([^"]+)".*?"latitude":([0-9.]+),"longitude":([0-9.]+)');
          final matches = regExp.allMatches(homeLocationsJson);

          for (final match in matches) {
            final id = match.group(1);
            if (id == selectedHomeLocationId) {
              homeLat = double.parse(match.group(2)!);
              homeLng = double.parse(match.group(3)!);
              debugPrint('🏠 JSON 파싱으로 홈 위치 찾음: lat=$homeLat, lng=$homeLng');
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('❌ 홈 위치 JSON 파싱 오류: $e');
      }
    }

    // 홈 위치 정보가 없으면 종료
    if (homeLat == null || homeLng == null) {
      debugPrint('⚠️ 집 위치 정보를 가져올 수 없습니다.');
      return;
    }

    // 현재 위치 확인
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    debugPrint('📍 현재 위치: ${position.latitude}, ${position.longitude}');

    // 집과의 거리 계산
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      homeLat,
      homeLng,
    );

    debugPrint(
        '📏 집과의 거리: ${distance.toStringAsFixed(2)}m (설정 반경: ${homeRadius}m)');

    // 알림을 이미 보냈는지 확인
    final alreadySentNotification =
        prefs.getBool('arrival_notification_sent') ?? false;
    final lastNotificationTimeStr =
        prefs.getString('last_arrival_notification_time');
    DateTime? lastNotificationTime;

    if (lastNotificationTimeStr != null) {
      try {
        lastNotificationTime = DateTime.parse(lastNotificationTimeStr);
      } catch (e) {
        debugPrint('⚠️ 마지막 알림 시간 파싱 오류: $e');
      }
    }

    // 집 반경 내에 있고 최근에 알림을 보내지 않았는지 확인
    final bool shouldSendNotification = distance <= homeRadius &&
        (!alreadySentNotification ||
            (lastNotificationTime != null &&
                DateTime.now().difference(lastNotificationTime).inMinutes >=
                    10));

    if (shouldSendNotification) {
      debugPrint('🏠 집 도착 감지! 알림 전송 중...');

      // 알림 서비스 초기화 및 알림 표시
      final notificationService = await NotificationService.getInstance();
      await notificationService.setupLocalNotifications();
      await notificationService.showNotification(
        id: 999,
        title: '🏠 귀가 알림',
        body: arrivalMessage,
        payload: 'home_arrival',
      );

      // 알림 상태 저장
      await prefs.setBool('arrival_notification_sent', true);
      await prefs.setString(
          'last_arrival_notification_time', DateTime.now().toIso8601String());
      await prefs.setBool('arrival_notification_pending', true);
      await prefs.setString('arrival_notification_message', arrivalMessage);
      await prefs.setStringList(
          'arrival_notification_recipients', recipientIds);

      // 메시지 전송 상태를 pending으로 설정하고 앱이 다시 실행될 때 메시지를 보내도록 함
      debugPrint('✅ 귀가 알림 전송 요청 저장 완료');

      // 메시지 전송을 시도 (Firebase 클라이언트 라이브러리를 직접 사용하는 방식은 워크매니저에서 제한됨)
      // 대신 앱이 다시 실행될 때 처리할 수 있도록 상태 저장

      // 추적 자동 중지를 위한 설정 변경
      await prefs.setBool('home_arrival_tracking_enabled', false);

      // 추적 종료 알림 표시
      await notificationService.showNotification(
        id: 1000,
        title: '귀가 추적 완료',
        body: '집에 도착하여 추적이 자동으로 중지되었습니다.',
        payload: 'home_arrival_stopped',
      );

      debugPrint('✅ 귀가 알림 전송 및 추적 자동 중지 완료');
    } else if (distance > homeRadius) {
      // 집 반경을 벗어나면 알림 상태 초기화
      await prefs.setBool('arrival_notification_sent', false);
      debugPrint('🔄 집 반경 밖으로 나가 알림 상태 초기화');
    }
  } catch (e) {
    debugPrint('❌ 위치 확인 작업 오류: $e');
    throw e; // 작업 실패로 처리
  }
}
