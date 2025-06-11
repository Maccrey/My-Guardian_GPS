import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  /// 지오펜스 등록
  Future<void> registerGeofence({
    required String id,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    // 실제 패키지 연동 필요 (예: flutter_geofence.registerGeofence)
    final region = GeofenceRegion(
      id: id,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
    );
    _regions.add(region);
    debugPrint('✅ 지오펜스 등록: $id ($latitude, $longitude, $radius m)');
    // TODO: 실제 플랫폼 지오펜스 등록 코드 추가
  }

  /// 지오펜스 해제
  Future<void> unregisterGeofence(String id) async {
    _regions.removeWhere((r) => r.id == id);
    debugPrint('✅ 지오펜스 해제: $id');
    // TODO: 실제 플랫폼 지오펜스 해제 코드 추가
  }

  /// 모든 지오펜스 해제
  Future<void> clearAllGeofences() async {
    _regions.clear();
    debugPrint('✅ 모든 지오펜스 해제');
    // TODO: 실제 플랫폼 지오펜스 전체 해제 코드 추가
  }

  /// 이벤트 콜백 등록
  void setEventHandler(void Function(GeofenceEvent event) handler) {
    onEvent = handler;
  }

  /// (예시) 플랫폼에서 이벤트 발생 시 호출 (실제 연동 시 플랫폼 채널/플러그인에서 호출)
  void handleGeofenceEvent({
    required String id,
    required double latitude,
    required double longitude,
    required double radius,
    required GeofenceEventType eventType,
  }) {
    final event = GeofenceEvent(
      id: id,
      latitude: latitude,
      longitude: longitude,
      radius: radius,
      eventType: eventType,
      timestamp: DateTime.now(),
    );
    debugPrint('📡 지오펜스 이벤트: $id, $eventType');
    if (onEvent != null) {
      onEvent!(event);
    }
  }
}
