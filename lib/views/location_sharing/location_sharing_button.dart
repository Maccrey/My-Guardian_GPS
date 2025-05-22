import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/location_sharing_service.dart';
import '../../services/message_service.dart';

/// 위치 공유 버튼 위젯
class LocationSharingButton extends StatelessWidget {
  final String contactId;
  final String contactName;
  final bool isAppUser;

  // 서비스 인스턴스
  final LocationSharingService _locationService =
      Get.find<LocationSharingService>();
  final MessageService _messageService = Get.find<MessageService>();

  LocationSharingButton({
    Key? key,
    required this.contactId,
    required this.contactName,
    required this.isAppUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 앱 사용자가 아닌 경우 위치 공유 불가
    if (!isAppUser) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      // 위치 공유 상태 확인 (개선된 로직)
      final isSharing = _locationService.isShareLocationActive(contactId);

      // MessageService를 통한 추가 확인
      final isActiveSharingFromMessage =
          _messageService.isLocationSharingActive(contactId);

      // 두 서비스에서 모두 확인 (논리적 OR)
      final isSharingActive = isSharing || isActiveSharingFromMessage;

      print(
          '🔄 [버튼] 위치 공유 상태: isSharing=$isSharing, fromMessage=$isActiveSharingFromMessage, 최종=$isSharingActive');

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ElevatedButton.icon(
          onPressed: () =>
              _handleLocationSharingToggle(context, isSharingActive),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSharingActive ? Colors.red : Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: Icon(
            isSharingActive ? Icons.location_off : Icons.location_on,
            size: 20,
          ),
          label: Text(
            isSharingActive ? '위치 공유 정지' : '위치 공유 시작',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    });
  }

  // 위치 공유 토글 처리
  Future<void> _handleLocationSharingToggle(
      BuildContext context, bool isSharing) async {
    if (isSharing) {
      // 위치 공유 중지
      _showStopSharingConfirmDialog(context);
    } else {
      // 위치 공유 시작
      _showStartSharingConfirmDialog(context);
    }
  }

  // 위치 공유 시작 확인 다이얼로그
  void _showStartSharingConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 공유 시작'),
        content: Text(
            '$contactName님에게 실시간 위치를 공유하시겠습니까?\n\n상대방에게는 위치 공유가 시작되었다는 알림이 전송됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result =
                  await _locationService.startLocationSharing(contactId);

              if (result) {
                Get.snackbar(
                  '위치 공유 시작',
                  '$contactName님에게 위치 공유가 시작되었습니다.',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.green.withOpacity(0.7),
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  '위치 공유 오류',
                  '위치 공유를 시작하지 못했습니다. 다시 시도해주세요.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.withOpacity(0.7),
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('시작'),
          ),
        ],
      ),
    );
  }

  // 위치 공유 중지 확인 다이얼로그
  void _showStopSharingConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 공유 중지'),
        content: Text(
            '$contactName님과의 위치 공유를 중지하시겠습니까?\n\n상대방에게는 위치 공유가 중지되었다는 알림이 전송됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result =
                  await _locationService.stopLocationSharing(contactId);

              if (result) {
                Get.snackbar(
                  '위치 공유 중지',
                  '$contactName님과의 위치 공유가 중지되었습니다.',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.blue.withOpacity(0.7),
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  '위치 공유 오류',
                  '위치 공유를 중지하지 못했습니다. 다시 시도해주세요.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.withOpacity(0.7),
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('중지'),
          ),
        ],
      ),
    );
  }
}
