import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/emergency_contact_model.dart';
import '../../services/emergency_contact_service.dart';
import '../../services/location_sharing_service.dart';
import '../../services/auth_service.dart';

class EmergencyContactLocationView extends StatefulWidget {
  const EmergencyContactLocationView({Key? key}) : super(key: key);

  @override
  State<EmergencyContactLocationView> createState() =>
      _EmergencyContactLocationViewState();
}

class _EmergencyContactLocationViewState
    extends State<EmergencyContactLocationView> with WidgetsBindingObserver {
  final EmergencyContactService _contactService =
      Get.find<EmergencyContactService>();
  final LocationSharingService _locationService =
      Get.find<LocationSharingService>();

  @override
  void initState() {
    super.initState();
    // 위젯 라이프사이클 관찰 시작
    WidgetsBinding.instance.addObserver(this);

    // 페이지 이동 시 매번 연락처 데이터 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 내 긴급 연락처 화면으로부터 돌아올 때 데이터 새로고침을 위해
      // 연락처 데이터 다시 로드
      _contactService.loadContacts();
    });
  }

  @override
  void dispose() {
    // 위젯 라이프사이클 관찰 종료
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화될 때 연락처 데이터 다시 로드
    if (state == AppLifecycleState.resumed) {
      // 연락처 데이터 새로고침
      _contactService.loadContacts();
      // 화면 갱신 - 최신 연락처 데이터 반영
      setState(() {});
    }
  }

  // 화면이 다시 포커스를 얻을 때 호출
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 다시 보여질 때 연락처 데이터 새로고침
    _contactService.loadContacts();
  }

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
        // 사용자 정의 연락처만 가져옴 (기본 긴급 연락처는 제외)
        // 매번 최신 데이터 사용을 위해 .value로 접근
        final userContacts = _contactService.userContacts.value;
        // isDefault가 false인 사용자 정의 연락처만 필터링
        final filteredUserContacts =
            userContacts.where((contact) => !contact.isDefault).toList();

        if (filteredUserContacts.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "내 긴급 연락처" 헤더 표시
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, top: 16, right: 16, bottom: 8),
              child: Text(
                '내 긴급 연락처',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                // 필터링된 목록 사용
                itemCount: filteredUserContacts.length,
                itemBuilder: (context, index) {
                  final contact = filteredUserContacts[index];
                  return _buildContactCard(context, contact);
                },
              ),
            ),
          ],
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
                  onPressed: contact.isDefault
                      ? null // 기본 연락처는 버튼 비활성화
                      : () => _handleLocationSharing(contact),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: isSharing
                        ? Theme.of(context).colorScheme.error
                        : contact.isDefault
                            ? Colors.grey.shade400 // 기본 연락처는 회색
                            : Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(
                    contact.isDefault
                        ? Icons.phone
                        : isSharing
                            ? Icons.location_off
                            : Icons.location_on,
                    color: Colors.white,
                  ),
                  label: Text(
                    contact.isDefault
                        ? '긴급 전화'
                        : isSharing
                            ? '위치 공유 중지'
                            : '위치 공유 시작',
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
            '등록된 내 긴급 연락처가 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '위치를 공유하려면 먼저 긴급 연락처 화면에서\n연락처를 추가하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/emergency-contacts'),
            icon: const Icon(Icons.add),
            label: const Text('긴급 연락처로 이동'),
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
