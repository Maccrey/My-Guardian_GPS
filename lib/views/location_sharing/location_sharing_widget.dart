import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/location_sharing_service.dart';

// 위치 공유 상태 표시 위젯
class LocationSharingStatusWidget extends StatelessWidget {
  final LocationSharingService _locationService =
      Get.find<LocationSharingService>();

  LocationSharingStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 위치 공유 중이 아닌 경우 표시하지 않음
      if (!_locationService.isSharingLocation.value) {
        return const SizedBox.shrink();
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // 깜박이는 위치 아이콘
            _buildBlinkingIcon(),
            const SizedBox(width: 12),

            // 위치 공유 상태 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '위치 공유 중',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_locationService.sharingToUserIds.length}명에게 실시간 위치 공유 중',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            // 중지 버튼
            TextButton(
              onPressed: () => _showStopSharingDialog(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
              child: Text(
                '중지',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // 깜박이는 위치 아이콘 위젯
  Widget _buildBlinkingIcon() {
    return Obx(() {
      return AnimatedOpacity(
        opacity: _locationService.isSharingLocation.value ? 1.0 : 0.2,
        duration: const Duration(milliseconds: 500),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Get.theme.colorScheme.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.location_on,
            color: Get.theme.colorScheme.primary,
            size: 24,
          ),
        ),
      );
    });
  }

  // 위치 공유 중지 확인 다이얼로그
  void _showStopSharingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 공유 중지'),
        content: const Text('모든 위치 공유를 중지하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              _locationService.stopAllLocationSharing();
              Navigator.of(context).pop();
            },
            child: const Text('중지'),
          ),
        ],
      ),
    );
  }
}
