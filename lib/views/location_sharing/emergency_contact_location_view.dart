import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/emergency_contact_model.dart';
import '../../services/emergency_contact_service.dart';
import '../../services/location_sharing_service.dart';
import '../../services/auth_service.dart';
import '../location_sharing/location_sharing_list_view.dart';

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

    print('🚀 [초기화] EmergencyContactLocationView 초기화');

    // 페이지 이동 시 매번 연락처 데이터 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 내 긴급 연락처 화면으로부터 돌아올 때 데이터 새로고침을 위해
      // 연락처 데이터 다시 로드
      print('📋 [데이터 로드] 연락처 데이터 로드 시작');
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
        title: const Text('위치 공유'),
        elevation: 0,
        actions: [
          // 사용자 검색 버튼
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: '다른 사용자 검색',
            onPressed: () => Get.toNamed('/location-sharing/user-search'),
          ),
        ],
      ),
      body: Obx(() {
        // 사용자 정의 연락처만 가져옴 (기본 긴급 연락처는 제외)
        // 매번 최신 데이터 사용을 위해 .value로 접근
        final userContacts = _contactService.userContacts.value;
        // isDefault가 false인 사용자 정의 연락처만 필터링
        final filteredUserContacts =
            userContacts.where((contact) => !contact.isDefault).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 위치 공유 상태 배너
            Obx(() {
              if (_locationService.isSharingLocation.value) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '위치 공유 활성화',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_locationService.sharingToUserIds.length - 1}명의 연락처와 위치 공유 중',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // 위치 공유 목록 화면으로 이동
                          try {
                            // 인증 상태 확인
                            final authService = Get.find<AuthService>();
                            if (authService.isAuthenticated) {
                              // 인증된 경우에만 위치 공유 목록 화면으로 이동
                              // 명시적으로 인스턴스를 생성하여 이동
                              Get.to(() => LocationSharingListView());
                            } else {
                              // 인증되지 않은 경우 안내 메시지 표시
                              Get.dialog(
                                AlertDialog(
                                  title: const Text('로그인 필요'),
                                  content:
                                      const Text('위치 공유 기능을 사용하려면 로그인이 필요합니다.'),
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
                            print('⚠️ 위치 공유 목록 화면으로 이동 중 오류: $e');
                            Get.snackbar(
                              '오류',
                              '위치 공유 목록 화면을 열 수 없습니다',
                              backgroundColor: Colors.red.withOpacity(0.8),
                              colorText: Colors.white,
                              snackPosition: SnackPosition.BOTTOM,
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.green.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '목록 보기',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            }),

            if (filteredUserContacts.isEmpty)
              Expanded(child: _buildEmptyState())
            else
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

            if (filteredUserContacts.isNotEmpty)
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

      // UI 빌드 시 현재 공유 상태 로깅
      print('📱 [UI] 연락처 카드 빌드: ${contact.name} - 위치 공유 중: $isSharing');

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
                    backgroundColor: isSharing
                        ? Theme.of(context).colorScheme.error.withOpacity(0.2)
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                    child: Icon(
                      // 앱 사용자와 일반 연락처를 구분하여 표시
                      contact.isAppUser ? Icons.account_circle : Icons.person,
                      color: isSharing
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
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
                          // 앱 사용자인 경우 표시 추가
                          contact.isAppUser
                              ? "${contact.phoneNumber} (앱 사용자)"
                              : contact.phoneNumber,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                        // 앱 사용자인 경우 이메일 표시
                        if (contact.isAppUser &&
                            contact.description != null &&
                            contact.description!.isNotEmpty)
                          Text(
                            contact.description!,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 위치 공유 버튼
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSharing
                      ? [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
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
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      contact.isDefault
                          ? Icons.phone
                          : isSharing
                              ? Icons.location_off
                              : Icons.location_on,
                      color: Colors.white,
                      key: ValueKey<bool>(isSharing), // 애니메이션을 위한 키
                    ),
                  ),
                  label: Text(
                    contact.isDefault
                        ? '긴급 전화'
                        : isSharing
                            ? '위치 공유 정지'
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
                          fontWeight: FontWeight.bold,
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
    // 연락처 정보 로깅
    print(
        '📞 [연락처 정보] id=${contact.id}, name=${contact.name}, userId=${contact.userId}, isAppUser=${contact.isAppUser}');

    final isSharing = _locationService.isShareLocationActive(contact.id);

    // 버튼 클릭 시 상태 로깅
    print('🔘 [버튼 클릭] ${contact.name} - 현재 위치 공유 상태: $isSharing');

    try {
      if (isSharing) {
        // 위치 공유 중지 시작
        print('🛑 [중지 요청] ${contact.name}님과의 위치 공유 중지 요청 시작');

        final result = await _locationService.stopLocationSharing(contact.id);

        // 중지 결과 로깅
        print('🛑 [중지 결과] ${contact.name} - 위치 공유 중지 결과: $result');

        // UI 갱신을 위해 setState 호출
        if (mounted) {
          setState(() {
            print('🔄 [UI 갱신] setState 호출 - 위치 공유 중지 후');
          });
        }

        // 위치 공유 상태 재확인
        final newStatus = _locationService.isShareLocationActive(contact.id);
        print('🔍 [상태 확인] ${contact.name} - 중지 후 위치 공유 상태: $newStatus');

        if (result) {
          Get.snackbar(
            '위치 공유 중지',
            '${contact.name}님과의 위치 공유가 중지되었습니다',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      } else {
        // 위치 공유 시작
        print('▶️ [시작 요청] ${contact.name}님과의 위치 공유 시작 요청');
        print(
            '▶️ [시작 매개변수] contactId=${contact.id}, userId=${contact.userId}, isAppUser=${contact.isAppUser}');

        final result =
            await _locationService.startLocationSharingWithEmergencyContact(
          contact.id,
          contact.userId,
          contact.isAppUser,
        );

        // 시작 결과 로깅
        print('▶️ [시작 결과] ${contact.name} - 위치 공유 시작 결과: $result');

        // UI 갱신을 위해 setState 호출
        if (mounted) {
          setState(() {
            print('🔄 [UI 갱신] setState 호출 - 위치 공유 시작 후');
          });
        }

        // 위치 공유 상태 재확인
        final newStatus = _locationService.isShareLocationActive(contact.id);
        print('🔍 [상태 확인] ${contact.name} - 시작 후 위치 공유 상태: $newStatus');

        if (result) {
          Get.snackbar(
            '위치 공유 시작',
            '${contact.name}님과 실시간 위치 공유가 시작되었습니다',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      }
    } catch (e) {
      print('❌ [오류] 위치 공유 처리 오류: $e');

      // 오류 발생 시에도 UI 갱신
      if (mounted) {
        setState(() {
          print('🔄 [UI 갱신] setState 호출 - 오류 발생 후');
        });
      }

      Get.snackbar(
        '위치 공유 오류',
        '위치 공유 처리 중 오류가 발생했습니다',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
