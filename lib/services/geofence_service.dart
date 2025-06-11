import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofence/geofence.dart';
// 실제 배포 시 flutter_geofence 또는 background_geolocation 등으로 교체 필요
// import 'package:flutter_geofence/flutter_geofence.dart';

/// 지오펜싱 이벤트 타입
enum GeofenceEventType { enter, exit }

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

  @override
  void onInit() {
    super.onInit();
    Geofence.initialize();
    Geofence.startListening(
        GeolocationEvent.entry, _onGeofenceEvent as GeofenceCallback);
    Geofence.startListening(
        GeolocationEvent.exit, _onGeofenceEvent as GeofenceCallback);
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
}
