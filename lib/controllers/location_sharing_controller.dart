import 'package:get/get.dart';
import '../services/location_sharing_service.dart';
import '../models/shared_location_model.dart';

class LocationSharingController extends GetxController {
  final LocationSharingService _locationService =
      Get.find<LocationSharingService>();

  // 위치 공유 상태
  RxBool get isSharingLocation => _locationService.isSharingLocation;

  // 위치 공유 중인 사용자 수
  RxInt get sharingCount => _locationService.sharingToUserIds.length.obs;

  // 위치 공유 시작
  Future<bool> startSharing(String contactId) async {
    return await _locationService.startLocationSharing(contactId);
  }

  // 위치 공유 중지
  Future<bool> stopSharing(String contactId) async {
    return await _locationService.stopLocationSharing(contactId);
  }

  // 모든 위치 공유 중지
  Future<void> stopAllSharing() async {
    await _locationService.stopAllLocationSharing();
  }

  // 위치 공유 상태 확인
  bool isShareLocationActive(String contactId) {
    return _locationService.isShareLocationActive(contactId);
  }

  // 특정 사용자의 실시간 위치 구독
  Stream<SharedLocation> subscribeToUserLocation(String userId) {
    return _locationService.subscribeToUserLocation(userId);
  }

  // 위치 업데이트 간격 설정
  void setUpdateInterval(int seconds) {
    _locationService.setUpdateInterval(seconds);
  }
}
