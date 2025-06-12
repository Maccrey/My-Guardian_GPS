import 'package:flutter_test/flutter_test.dart';
import 'package:watch_over/services/geofence_service.dart';

void main() {
  group('GeofenceService', () {
    late GeofenceService service;

    setUp(() {
      service = GeofenceService();
    });

    test('지오펜스 등록 시 내부 목록에 추가된다', () async {
      await service.registerGeofence(
        id: 'test-home',
        latitude: 37.0,
        longitude: 127.0,
        radius: 30.0,
      );
      expect(service.regions.any((r) => r.id == 'test-home'), isTrue);
    });

    test('지오펜스 해제 시 내부 목록에서 제거된다', () async {
      await service.registerGeofence(
        id: 'test-home',
        latitude: 37.0,
        longitude: 127.0,
        radius: 30.0,
      );
      await service.unregisterGeofence('test-home');
      expect(service.regions.any((r) => r.id == 'test-home'), isFalse);
    });

    test('이벤트 콜백 등록 및 트리거', () async {
      bool called = false;
      service.setEventHandler((event) {
        called = true;
        expect(event.id, 'test-home');
        expect(event.eventType, GeofenceEventType.enter);
      });
      await service.registerGeofence(
        id: 'test-home',
        latitude: 37.0,
        longitude: 127.0,
        radius: 30.0,
      );
      // 직접 이벤트 트리거 (플랫폼 연동 없이)
      await service.triggerGeofenceEvent({
        'id': 'test-home',
        'event': GeolocationEvent.entry.toString(),
      });
      expect(called, isTrue);
    });
  });
}
