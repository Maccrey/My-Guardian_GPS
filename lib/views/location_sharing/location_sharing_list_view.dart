import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/location_sharing_controller.dart';
import '../../models/shared_location_model.dart';
import '../../services/auth_service.dart';
import '../../services/location_sharing_service.dart';

class LocationSharingListView extends StatelessWidget {
  final LocationSharingController controller =
      Get.find<LocationSharingController>();
  final AuthService _authService = Get.find<AuthService>();
  final LocationSharingService _locationService =
      Get.find<LocationSharingService>();

  LocationSharingListView({Key? key}) : super(key: key) {
    // 인증 상태 확인
    if (!_authService.isAuthenticated) {
      // 인증되지 않은 경우 스낵바 표시
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.snackbar(
          '로그인 필요',
          '위치 공유 기능을 사용하려면 로그인이 필요합니다',
          backgroundColor: Colors.red.withOpacity(0.8),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
        // 로그인 페이지로 이동
        Get.offAllNamed('/');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 인증 상태 확인 - 한 번 더 보호 장치 추가
    if (!_authService.isAuthenticated) {
      return const Scaffold(
        body: Center(
          child: Text('로그인이 필요합니다...'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('위치 공유 목록'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 화면 강제 새로고침
              controller.update();
              Get.forceAppUpdate();
            },
          ),
        ],
      ),
      body: Obx(() {
        // 현재 사용자 ID 가져오기
        final currentUserId = _authService.currentUser?.uid;

        // 활성 공유 목록 가져오기
        final activeSharing = controller.activeSharing;

        // 현재 사용자가 수신자이거나 발신자인 항목 필터링 (단, 자기 자신과의 공유는 제외)
        final sharedLocationIds = <String>[];

        for (final entry in activeSharing.entries) {
          final sharedLocation = entry.value;
          // 현재 사용자가 발신자이거나 수신자인 경우 추가 (단, 자기 자신과의 공유는 제외)
          if ((sharedLocation.senderId == currentUserId ||
                  sharedLocation.receiverId == currentUserId) &&
              !(sharedLocation.senderId == currentUserId &&
                  sharedLocation.receiverId == currentUserId) &&
              // 수신자가 자신의 ID와 같은 경우도 제외 (본인 연락처는 표시하지 않음)
              sharedLocation.receiverId != currentUserId) {
            sharedLocationIds.add(entry.key);
          }
        }

        if (sharedLocationIds.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  '현재 위치 공유 중인 연락처가 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: sharedLocationIds.length,
          itemBuilder: (context, index) {
            final locationId = sharedLocationIds[index];
            return FutureBuilder<String>(
                future: controller.getReceiverName(locationId),
                builder: (context, snapshot) {
                  final receiverName = snapshot.data ?? '연락처';
                  final sharedLocation = activeSharing[locationId];

                  // 본인 연락처인 경우 표시하지 않음 (receiverName이 '연락처'인 경우 건너뛰기)
                  if (receiverName == '연락처' &&
                      sharedLocation?.senderId == currentUserId) {
                    return const SizedBox.shrink(); // 빈 위젯 반환하여 표시하지 않음
                  }

                  return LocationSharingListItem(
                    receiverId: locationId,
                    receiverName: receiverName,
                    sharedLocation: sharedLocation,
                    onStopSharing: () async {
                      final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('위치 공유 중지'),
                              content:
                                  Text('$receiverName님과의 위치 공유를 중지하시겠습니까?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('취소'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('중지'),
                                ),
                              ],
                            ),
                          ) ??
                          false;

                      if (confirmed) {
                        await controller.stopSharing(locationId);
                        Get.snackbar(
                          '위치 공유 중지',
                          '$receiverName님과의 위치 공유가 중지되었습니다',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    },
                  );
                });
          },
        );
      }),
      floatingActionButton: Obx(
        () => controller.sharingToUserIds.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('모든 위치 공유 중지'),
                          content: const Text('모든 위치 공유를 중지하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('중지'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (confirmed) {
                    await controller.stopAllSharing();
                    Get.snackbar(
                      '위치 공유 중지',
                      '모든 위치 공유가 중지되었습니다',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                },
                icon: const Icon(Icons.location_off),
                label: const Text('모든 공유 중지'),
                backgroundColor: Colors.redAccent,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class LocationSharingListItem extends StatelessWidget {
  final String receiverId;
  final String receiverName;
  final SharedLocation? sharedLocation;
  final VoidCallback onStopSharing;

  const LocationSharingListItem({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    this.sharedLocation,
    required this.onStopSharing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final startTime = sharedLocation?.startTime;
    final formattedTime = startTime != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(startTime)
        : '알 수 없음';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.blue,
            size: 30,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                receiverName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '공유중',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('시작 시간: $formattedTime'),
            const SizedBox(height: 4),
            Text(
              '위치 ID: ${sharedLocation?.id.substring(0, 8) ?? '알 수 없음'}...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.stop_circle),
          color: Colors.red,
          tooltip: '공유 중지',
          onPressed: onStopSharing,
        ),
        onTap: () {
          // 위치 상세 정보 표시 또는 지도 화면 열기
          if (sharedLocation != null) {
            showModalBottomSheet(
              context: context,
              builder: (context) => LocationDetailBottomSheet(
                receiverName: receiverName,
                sharedLocation: sharedLocation!,
                onStopSharing: onStopSharing,
              ),
            );
          }
        },
      ),
    );
  }
}

class LocationDetailBottomSheet extends StatelessWidget {
  final String receiverName;
  final SharedLocation sharedLocation;
  final VoidCallback onStopSharing;

  const LocationDetailBottomSheet({
    Key? key,
    required this.receiverName,
    required this.sharedLocation,
    required this.onStopSharing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final startTime = DateFormat('yyyy-MM-dd HH:mm')
        .format(sharedLocation.startTime ?? DateTime.now());
    final timeSinceStart =
        DateTime.now().difference(sharedLocation.startTime ?? DateTime.now());

    String duration = '';
    if (timeSinceStart.inHours > 0) {
      duration =
          '${timeSinceStart.inHours}시간 ${timeSinceStart.inMinutes % 60}분';
    } else {
      duration = '${timeSinceStart.inMinutes}분';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$receiverName님과 위치 공유 중',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoRow(Icons.timer, '시작 시간', startTime),
          _buildInfoRow(Icons.hourglass_full, '공유 시간', duration),
          _buildInfoRow(Icons.location_on, '현재 위치',
              '위도: ${sharedLocation.latitude.toStringAsFixed(6)}, 경도: ${sharedLocation.longitude.toStringAsFixed(6)}'),
          _buildInfoRow(
            Icons.tag,
            '공유 ID',
            sharedLocation.id.length > 20
                ? '${sharedLocation.id.substring(0, 20)}...'
                : sharedLocation.id,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // 지도 화면으로 이동하는 기능 추가 (별도 구현 필요)
                  Get.toNamed('/map', arguments: {
                    'latitude': sharedLocation.latitude,
                    'longitude': sharedLocation.longitude,
                    'title': receiverName,
                  });
                },
                icon: const Icon(Icons.map),
                label: const Text('지도에서 보기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onStopSharing();
                },
                icon: const Icon(Icons.stop_circle),
                label: const Text('공유 중지'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueGrey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
