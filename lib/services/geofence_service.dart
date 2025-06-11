import 'package:get/get.dart';
import 'package:flutter/material.dart';
// 외부 플러그인에 의존하지 않는 자체 구현
// 실제 지오펜스 기능은 추후 안정적인 라이브러리 사용 예정

/// 지오펜싱 이벤트 타입
enum GeofenceEventType { enter, exit }

/// 모의 Geolocation 클래스
class Geolocation {
  final double latitude;
  final double longitude;
  final double radius;
  final String id;

  Geolocation({
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.id,
  });
}

/// 모의 GeolocationEvent
class GeolocationEvent {
  static const entry = 'ENTRY';
  static const exit = 'EXIT';

  @override
  String toString() => this == entry ? 'ENTRY' : 'EXIT';
}

/// 모의 Geofence 클래스 (플러그인 대체)
class Geofence {
  static void initialize() {
    debugPrint('✅ 모의 Geofence 초기화됨');
  }

  static Future<void> startListening(
      String event, Function(Geolocation) callback) async {
    debugPrint('✅ 모의 Geofence 리스너 등록: $event');
    return;
  }

  static Future<void> addGeolocation(
      Geolocation geolocation, String event) async {
    debugPrint(
        '✅ 모의 지오펜스 추가: ${geolocation.id} (${geolocation.latitude}, ${geolocation.longitude}, ${geolocation.radius}m)');
    return;
  }

  static Future<void> removeGeolocation(
      Geolocation geolocation, String event) async {
    debugPrint('✅ 모의 지오펜스 제거: ${geolocation.id}');
    return;
  }

  static Future<void> removeAllGeolocations() async {
    debugPrint('✅ 모의 모든 지오펜스 제거');
    return;
  }
}

/// 지오펜싱 이벤트 데이터
class GeofenceEvent {
  final String id;
  final double latitude;
  final double longitude;
  final double radius;
  final GeofenceEventType eventType;
  final DateTime timestamp;

  GeofenceEvent({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.eventType,
    required this.timestamp,
  });
}

/// 지오펜스 정보
class GeofenceRegion {
  final String id;
  final double latitude;
  final double longitude;
  final double radius;

  GeofenceRegion({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });
}

/// GeofenceService: 집 위치(원형 영역) 등록 및 진입/이탈 이벤트 감지
class GeofenceService extends GetxController {
  static GeofenceService? _instance;
  static GeofenceService get instance => _instance ??= GeofenceService();

  // 등록된 지오펜스 목록
  final RxList<GeofenceRegion> _regions = <GeofenceRegion>[].obs;

  // 이벤트 콜백(진입/이탈 시 호출)
  void Function(GeofenceEvent event)? onEvent;

  // 등록된 지오펜스 목록 (외부 접근용 getter)
  List<GeofenceRegion> get regions => _regions;

  @override
  void onInit() {
    super.onInit();
    // 모의 Geofence 초기화
    Geofence.initialize();

    // 콜백 타입 문제 해결을 위해 수정
    try {
      // 모의 리스너 등록
      Geofence.startListening(GeolocationEvent.entry, (geolocation) {
        debugPrint('✅ 모의 지오펜스 리스너 작동 (ENTRY)');
      });

      Geofence.startListening(GeolocationEvent.exit, (geolocation) {
        debugPrint('✅ 모의 지오펜스 리스너 작동 (EXIT)');
      });

      debugPrint('✅ 지오펜스 리스너 등록 성공');
    } catch (e) {
      debugPrint('❌ 지오펜스 리스너 등록 실패: $e');
    }
  }

  /// 지오펜스 등록
  Future<void> registerGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    final region = GeofenceRegion(
      id: id,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
    );
    _regions.add(region);

    // 모의 지오펜스 등록
    await Geofence.addGeolocation(
      Geolocation(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        id: id,
      ),
      GeolocationEvent.entry,
    );

    await Geofence.addGeolocation(
      Geolocation(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
        id: id,
      ),
      GeolocationEvent.exit,
    );

    debugPrint('✅ 지오펜스 등록: $id ($latitude, $longitude, $radius m)');
  }

  /// 지오펜스 해제
  Future<void> unregisterGeofence(String id) async {
    final region = _regions.firstWhereOrNull((r) => r.id == id);
    if (region != null) {
      final geolocation = Geolocation(
        latitude: region.latitude,
        longitude: region.longitude,
        radius: region.radius,
        id: region.id,
      );
      await Geofence.removeGeolocation(geolocation, GeolocationEvent.entry);
      await Geofence.removeGeolocation(geolocation, GeolocationEvent.exit);
      _regions.remove(region);
      debugPrint('✅ 지오펜스 해제: $id');
    }
  }

  /// 모든 지오펜스 해제
  Future<void> clearAllGeofences() async {
    _regions.clear();
    await Geofence.removeAllGeolocations();
    debugPrint('✅ 모든 지오펜스 해제');
  }

  /// 이벤트 콜백 등록
  void setEventHandler(void Function(GeofenceEvent event) handler) {
    onEvent = handler;
    debugPrint('✅ 지오펜스 이벤트 핸들러 등록됨');
  }

  Future<dynamic> _onGeofenceEvent(Map<String, dynamic> event) async {
    final eventType = event['event'] == GeolocationEvent.entry.toString()
        ? GeofenceEventType.enter
        : GeofenceEventType.exit;
    final region = _regions.firstWhereOrNull((r) => r.id == event['id']);
    if (region == null) return;
    final geofenceEvent = GeofenceEvent(
      id: event['id'],
      latitude: region.latitude,
      longitude: region.longitude,
      radius: region.radius,
      eventType: eventType,
      timestamp: DateTime.now(),
    );
    debugPrint('📡 지오펜스 이벤트: ${event['id']}, $eventType');
    if (onEvent != null) {
      onEvent!(geofenceEvent);
    }
    return Future.value();
  }

  // 테스트용: 외부에서 임의로 지오펜스 이벤트를 트리거할 수 있도록 public 메서드 추가
  Future<void> triggerGeofenceEvent(Map<String, dynamic> event) async {
    await _onGeofenceEvent(event);
  }
}
