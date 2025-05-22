import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/location_message_model.dart';

/// 위치 공유 메시지 아이템 위젯
class LocationSharingMessageItem extends StatelessWidget {
  final LocationMessage message;
  final bool isCurrentUserSender;
  final String senderName;

  const LocationSharingMessageItem({
    Key? key,
    required this.message,
    required this.isCurrentUserSender,
    required this.senderName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isStarting = message.action == 'start';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrentUserSender
              ? [Colors.blue.shade700, Colors.blue.shade500]
              : [Colors.teal.shade200, Colors.teal.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 메시지 제목 및 아이콘
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStarting ? Icons.location_on : Icons.location_off,
                size: 22,
                color:
                    isCurrentUserSender ? Colors.white : Colors.teal.shade800,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isStarting
                      ? '$senderName님이 위치 공유를 시작했습니다.'
                      : '$senderName님이 위치 공유를 중지했습니다.',
                  style: TextStyle(
                    color: isCurrentUserSender
                        ? Colors.white
                        : Colors.teal.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),

          // 위치 정보 (위치 공유 시작 메시지인 경우에만 표시)
          if (isStarting && message.locationId != null) ...[
            const SizedBox(height: 8),

            // 지도에서 보기 버튼
            GestureDetector(
              onTap: () => _navigateToLocationMap(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isCurrentUserSender
                      ? Colors.white.withOpacity(0.25)
                      : Colors.teal.shade800.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.map,
                      size: 18,
                      color: isCurrentUserSender
                          ? Colors.white
                          : Colors.teal.shade800,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '지도에서 위치 보기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCurrentUserSender
                            ? Colors.white
                            : Colors.teal.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 위치 지도 화면으로 이동
  void _navigateToLocationMap(BuildContext context) {
    if (message.action != 'start' || message.locationId == null) {
      // 위치 공유가 중지되었거나 ID가 없는 경우
      Get.snackbar(
        '위치 정보 없음',
        '위치 공유가 중지되었거나 위치 정보가 없습니다.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.7),
        colorText: Colors.white,
      );
      return;
    }

    print('🗺️ [메시지] 위치 지도 화면으로 이동: locationId=${message.locationId}');

    // 위치 추적 화면으로 이동
    Get.toNamed('/location-tracking', arguments: {
      'userId': message.senderId,
      'contactName': senderName,
      'locationId': message.locationId,
    });
  }
}
