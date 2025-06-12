import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/location_sharing_service.dart';
import '../../services/message_service.dart';
import '../../services/auth_service.dart';
import 'location_sharing_list_view.dart';

/// 위치 공유 버튼 위젯
class LocationSharingButton extends StatefulWidget {
  final String contactId;
  final String contactName;
  final bool isAppUser;

  const LocationSharingButton({
    Key? key,
    required this.contactId,
    required this.contactName,
    required this.isAppUser,
  }) : super(key: key);

  @override
  State<LocationSharingButton> createState() => _LocationSharingButtonState();
}

class _LocationSharingButtonState extends State<LocationSharingButton> {
  // 서비스 인스턴스
  late LocationSharingService _locationService;
  late MessageService _messageService;
  final AuthService _authService = Get.find<AuthService>();

  // 초기화 상태
  final RxBool _isInitialized = false.obs;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // 서비스 초기화 - 싱글톤 대신 직접 Get.find 사용
      _locationService = Get.find<LocationSharingService>();
      _messageService = Get.find<MessageService>();

      _isInitialized.value = true;
      debugPrint('✅ LocationSharingButton 서비스 초기화 성공');
    } catch (e) {
      debugPrint('❌ LocationSharingButton 서비스 초기화 오류: $e');
      // 오류 발생 시 강제로 서비스 등록 시도
      if (!Get.isRegistered<LocationSharingService>()) {
        Get.put(LocationSharingService(), permanent: true);
        _locationService = Get.find<LocationSharingService>();
      }
      _isInitialized.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 앱 사용자가 아닌 경우 위치 공유 불가
    if (!widget.isAppUser) {
      return const SizedBox.shrink();
    }

    // 초기화 중이면 로딩 표시
    if (!_isInitialized.value) {
      return const SizedBox(
        height: 40,
        width: 40,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Obx(() {
      // 위치 공유 상태 확인 (개선된 로직)
      final isSharing =
          _locationService.isShareLocationActive(widget.contactId);

      // MessageService를 통한 추가 확인
      final isActiveSharingFromMessage =
          _messageService.isLocationSharingActive(widget.contactId);

      // 두 서비스에서 모두 확인 (논리적 OR)
      final isSharingActive = isSharing || isActiveSharingFromMessage;

      debugPrint(
          '🔄 [버튼] 위치 공유 상태: isSharing=$isSharing, fromMessage=$isActiveSharingFromMessage, 최종=$isSharingActive');

      // 위치 공유 중일 때는 버튼 세트를 보여줌
      if (isSharingActive) {
        return Column(
          children: [
            Row(
              children: [
                // 지도 보기 버튼
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _navigateToLocationMap(context, widget.contactId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(
                      Icons.map,
                      size: 20,
                    ),
                    label: const Text(
                      '지도 보기',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 공유 정지 버튼
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _handleLocationSharingToggle(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(
                      Icons.location_off,
                      size: 20,
                    ),
                    label: const Text(
                      '공유 정지',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 모든 위치 공유 관리 버튼 추가
            if (_locationService.sharingToUserIds.length > 1)
              TextButton.icon(
                onPressed: () {
                  // 위치 공유 목록 페이지로 이동
                  try {
                    // 인증 상태 확인
                    if (_authService.isAuthenticated) {
                      // 인증된 경우에만 위치 공유 목록 화면으로 이동
                      Get.to(() => const LocationSharingListView());
                    } else {
                      // 인증되지 않은 경우 안내 메시지 표시
                      Get.dialog(
                        AlertDialog(
                          title: const Text('로그인 필요'),
                          content: const Text('위치 공유 기능을 사용하려면 로그인이 필요합니다.'),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text('취소'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Get.back();
                                Get.offAllNamed('/');
                              },
                              child: const Text('로그인'),
                            ),
                          ],
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint('⚠️ 위치 공유 목록 화면으로 이동 중 오류: $e');
                    Get.snackbar(
                      '오류',
                      '위치 공유 목록 화면을 열 수 없습니다',
                      backgroundColor: Colors.red.withOpacity(0.8),
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                },
                icon: const Icon(
                  Icons.list,
                  size: 16,
                ),
                label: Text(
                  '모든 위치 공유 관리 (${_locationService.sharingToUserIds.length})',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            // 상태 표시
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                '${widget.contactName}님과 위치 공유 중',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      } else {
        // 위치 공유 중이 아닐 때는 단일 버튼 표시
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: ElevatedButton.icon(
            onPressed: () => _handleLocationSharingToggle(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(
              Icons.location_on,
              size: 20,
            ),
            label: const Text(
              '위치 공유 시작',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
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

  // 위치 지도 화면으로 이동
  void _navigateToLocationMap(BuildContext context, String userId) {
    // 위치 공유 ID 가져오기
    String? locationId = _messageService.getLocationSharingId(userId);

    if (locationId == null) {
      // MessageService에서 ID를 가져올 수 없는 경우 LocationSharingService에서 시도
      locationId = _locationService.getLocationId(userId);
    }

    debugPrint(
        '🗺️ [버튼] 위치 지도 화면으로 이동: userId=$userId, locationId=$locationId');

    // 위치 추적 화면으로 이동
    Get.toNamed('/location-tracking', arguments: {
      'userId': userId,
      'contactName': widget.contactName,
      'locationId': locationId,
    });
  }

  // 위치 공유 시작 확인 다이얼로그
  void _showStartSharingConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 공유 시작'),
        content: Text(
            '${widget.contactName}님에게 실시간 위치를 공유하시겠습니까?\n\n상대방에게는 위치 공유가 시작되었다는 알림이 전송됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result =
                  await _locationService.startLocationSharing(widget.contactId);

              if (result) {
                Get.snackbar(
                  '위치 공유 시작',
                  '${widget.contactName}님에게 위치 공유가 시작되었습니다.',
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
            '${widget.contactName}님과의 위치 공유를 중지하시겠습니까?\n\n위치 공유 데이터가 삭제되고 상대방에게는 위치 공유가 중지되었다는 알림이 전송됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final result =
                  await _locationService.stopLocationSharing(widget.contactId);

              if (result) {
                Get.snackbar(
                  '위치 공유 중지',
                  '${widget.contactName}님과의 위치 공유가 중지되고 데이터가 삭제되었습니다.',
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
