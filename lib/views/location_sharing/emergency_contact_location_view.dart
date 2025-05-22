import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/emergency_contact_model.dart';
import '../../services/emergency_contact_service.dart';
import '../../services/location_sharing_service.dart';
import '../../services/auth_service.dart';

class EmergencyContactLocationView extends StatelessWidget {
  final EmergencyContactService _contactService =
      Get.find<EmergencyContactService>();
  final LocationSharingService _locationService =
      Get.find<LocationSharingService>();

  EmergencyContactLocationView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 로그인 상태 확인
    final authService = Get.find<AuthService>();

    if (!authService.isAuthenticated) {
      // 로그인되지 않은 경우 안내 화면 표시
      return Scaffold(
        appBar: AppBar(
          title: const Text('로그인 필요'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                '위치 공유 기능을 사용하려면\n로그인이 필요합니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Get.offAllNamed('/',
                    parameters: {'returnRoute': 'location-sharing'}),
                child: Text('로그인 화면으로 이동'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('긴급 연락처 위치 공유'),
        elevation: 0,
      ),
      body: Obx(() {
        final contacts = _contactService.userContacts;

        if (contacts.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: contacts.length,
          itemBuilder: (context, index) {
            final contact = contacts[index];
            return _buildContactCard(context, contact);
          },
        );
      }),
    );
  }

  // 연락처 카드 위젯
  Widget _buildContactCard(BuildContext context, EmergencyContact contact) {
    return Obx(() {
      final isSharing = _locationService.isShareLocationActive(contact.id);

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    child: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          contact.phoneNumber,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 위치 공유 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _handleLocationSharing(contact),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: isSharing
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    isSharing ? Icons.location_off : Icons.location_on,
                    color: Colors.white,
                  ),
                  label: Text(
                    isSharing ? '위치 공유 중지' : '위치 공유 시작',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 위치 공유 상태 표시
              if (isSharing)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '실시간 위치 공유 중',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  // 빈 상태 위젯
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contact_phone,
            size: 64,
            color: Get.theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '등록된 긴급 연락처가 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '위치를 공유하려면 먼저 긴급 연락처를 추가하세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/emergency-contacts/add'),
            icon: const Icon(Icons.add),
            label: const Text('연락처 추가'),
          ),
        ],
      ),
    );
  }

  // 위치 공유 처리 함수
  void _handleLocationSharing(EmergencyContact contact) async {
    final isSharing = _locationService.isShareLocationActive(contact.id);

    if (isSharing) {
      // 위치 공유 중지
      final result = await _locationService.stopLocationSharing(contact.id);
      if (result) {
        Get.snackbar(
          '위치 공유 중지',
          '${contact.name}님과의 위치 공유가 중지되었습니다',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } else {
      // 위치 공유 시작
      final result = await _locationService.startLocationSharing(contact.id);
      if (result) {
        Get.snackbar(
          '위치 공유 시작',
          '${contact.name}님과 실시간 위치 공유가 시작되었습니다',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }
}
