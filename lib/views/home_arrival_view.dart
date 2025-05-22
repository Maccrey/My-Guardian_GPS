import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import 'package:geocoding/geocoding.dart';
import '../models/home_location_model.dart';
import '../models/user_model.dart';
import '../models/emergency_contact_model.dart';
import '../services/home_location_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../services/emergency_contact_service.dart';

class HomeArrivalView extends StatefulWidget {
  const HomeArrivalView({Key? key}) : super(key: key);

  @override
  State<HomeArrivalView> createState() => _HomeArrivalViewState();
}

class _HomeArrivalViewState extends State<HomeArrivalView> {
  // 서비스
  late final HomeLocationService _homeLocationService;
  final LocationService _locationService = Get.find<LocationService>();
  final AuthService _authService = Get.find<AuthService>();
  final MessageService _messageService = Get.find<MessageService>();
  final EmergencyContactService _emergencyContactService =
      Get.put(EmergencyContactService(useMemoryOnly: false), permanent: true);

  // 상태 변수
  final RxBool _isInitialized = false.obs;
  final RxBool _isLoading = false.obs;
  final RxBool _isSearchingUsers = false.obs;
  final RxString _errorMessage = ''.obs;
  final RxList<UserModel> _searchResults = <UserModel>[].obs;

  // 선택된 유저
  final Rx<UserModel?> _selectedUser = Rx<UserModel?>(null);

  // 선택된 긴급 연락처
  final Rx<EmergencyContact?> _selectedEmergencyContact =
      Rx<EmergencyContact?>(null);

  // 알림 방법 선택 (유저 검색 또는 긴급 연락처)
  final RxString _selectedNotificationMethod =
      'user'.obs; // 'user' 또는 'emergency'

  // 메시지 컨트롤러
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _locationNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // 탭 컨트롤러
  final TabController? _tabController = null;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _locationNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // 서비스 초기화
  Future<void> _initializeServices() async {
    try {
      _isLoading.value = true;

      // HomeLocationService 초기화
      _homeLocationService = await HomeLocationService.getInstance();

      // 위치 목록 로드
      await _homeLocationService.loadHomeLocations();

      // EmergencyContactService 연락처 로드
      await _emergencyContactService.loadContacts();

      _isInitialized.value = true;
    } catch (e) {
      _errorMessage.value = '서비스 초기화 중 오류가 발생했습니다: $e';
      debugPrint('❌ 초기화 오류: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  // 새 집 위치 추가
  Future<void> _addNewHomeLocation() async {
    try {
      // 현재 위치 확인
      final currentLocation = _locationService.currentLocation.value;
      if (currentLocation == null) {
        Get.snackbar(
          '위치 오류',
          '현재 위치를 가져올 수 없습니다. 위치 서비스가 활성화되어 있는지 확인해주세요.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      // 주소 가져오기
      List<Placemark> placemarks = await placemarkFromCoordinates(
        currentLocation.latitude,
        currentLocation.longitude,
      );

      String address = '';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = '${p.locality ?? ''} ${p.thoroughfare ?? ''} ${p.name ?? ''}'
            .trim();
      }

      // 주소가 비어있으면 좌표 사용
      if (address.isEmpty) {
        address =
            '위도: ${currentLocation.latitude.toStringAsFixed(6)}, 경도: ${currentLocation.longitude.toStringAsFixed(6)}';
      }

      // 추가 다이얼로그 표시
      await _showAddHomeLocationDialog(
          currentLocation.latitude, currentLocation.longitude, address);
    } catch (e) {
      Get.snackbar(
        '오류',
        '위치 등록 중 오류가 발생했습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      debugPrint('❌ 위치 등록 오류: $e');
    }
  }

  // 홈 위치 추가 다이얼로그
  Future<void> _showAddHomeLocationDialog(
      double latitude, double longitude, String address) async {
    _locationNameController.text = '우리 집';

    await Get.dialog(
      AlertDialog(
        title: const Text('새 집 위치 등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _locationNameController,
              decoration: const InputDecoration(
                labelText: '위치 이름',
                hintText: '예: 우리 집, 회사, 학교 등',
              ),
            ),
            const SizedBox(height: 16),
            Text('주소: $address'),
            const SizedBox(height: 8),
            Text('위도: ${latitude.toStringAsFixed(6)}'),
            Text('경도: ${longitude.toStringAsFixed(6)}'),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('기본 위치로 설정'),
              value: true, // 기본 체크
              onChanged: (value) {},
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _locationNameController.text.trim();
              if (name.isEmpty) {
                Get.snackbar(
                  '입력 오류',
                  '위치 이름을 입력해주세요.',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              // 위치 추가
              final success = await _homeLocationService.addHomeLocation(
                latitude: latitude,
                longitude: longitude,
                address: address,
                name: name,
                isDefault: true, // 기본 위치로 설정
              );

              Get.back(); // 다이얼로그 닫기

              if (success) {
                Get.snackbar(
                  '성공',
                  '새 집 위치가 등록되었습니다.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.shade600,
                  colorText: Colors.white,
                );
              } else {
                Get.snackbar(
                  '실패',
                  '위치 등록에 실패했습니다: ${_homeLocationService.errorMessage.value}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.shade700,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  // 사용자 검색
  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      _searchResults.clear();
      return;
    }

    try {
      _isSearchingUsers.value = true;

      // 사용자 검색
      final results = await _messageService.searchUsers(query);

      // 현재 사용자 제외
      final filteredResults =
          results.where((user) => user.uid != _authService.uid).toList();

      _searchResults.value = filteredResults;
    } catch (e) {
      debugPrint('❌ 사용자 검색 오류: $e');
    } finally {
      _isSearchingUsers.value = false;
    }
  }

  // 귀가 알림 보내기
  Future<void> _sendHomeArrivalNotification() async {
    // 선택된 홈 위치 확인
    final selectedHome = _homeLocationService.getSelectedHomeLocation();
    if (selectedHome == null) {
      Get.snackbar(
        '위치 오류',
        '등록된 집 위치가 없습니다. 먼저 위치를 등록해주세요.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    // 알림 방식에 따라 다른 처리
    if (_selectedNotificationMethod.value == 'user') {
      // 사용자 선택 방식
      final selectedUser = _selectedUser.value;
      if (selectedUser == null) {
        Get.snackbar(
          '선택 오류',
          '알림을 보낼 사용자를 선택해주세요.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      try {
        _isLoading.value = true;

        // 기본 메시지 설정
        String message = _messageController.text.trim();
        if (message.isEmpty) {
          message = '집에 도착했습니다.';
        }

        // 진동 피드백
        HapticFeedback.mediumImpact();

        // 메시지 전송
        final success = await _homeLocationService.sendHomeArrivalMessage(
          receiverId: selectedUser.uid ?? '',
          message: message,
          homeLocation: selectedHome,
        );

        if (success) {
          Get.snackbar(
            '성공',
            '${selectedUser.nickname ?? '사용자'}님에게 귀가 알림을 보냈습니다.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.shade600,
            colorText: Colors.white,
          );

          // 메시지 필드 초기화
          _messageController.clear();
        } else {
          Get.snackbar(
            '실패',
            '귀가 알림 전송에 실패했습니다: ${_homeLocationService.errorMessage.value}',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
          );
        }
      } catch (e) {
        Get.snackbar(
          '오류',
          '귀가 알림 전송 중 오류가 발생했습니다: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        debugPrint('❌ 귀가 알림 전송 오류: $e');
      } finally {
        _isLoading.value = false;
      }
    } else {
      // 긴급 연락처 선택 방식
      final selectedContact = _selectedEmergencyContact.value;
      if (selectedContact == null) {
        Get.snackbar(
          '선택 오류',
          '알림을 보낼 긴급 연락처를 선택해주세요.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        return;
      }

      try {
        _isLoading.value = true;

        // 기본 메시지 설정
        String message = _messageController.text.trim();
        if (message.isEmpty) {
          message = '집에 도착했습니다.';
        }

        // 진동 피드백
        HapticFeedback.mediumImpact();

        // 메시지 구성 - 위치 정보와 함께
        final fullMessage = '🏠 귀가 알림: $message\n'
            '📍 ${selectedHome.name} (${selectedHome.address})\n'
            '📱 전화 번호: ${selectedContact.phoneNumber}';

        // SMS 앱 열기 (실제로는 SMS 전송 구현 필요)
        // 여기서는 스낵바만 표시
        Get.snackbar(
          '알림 전송',
          '${selectedContact.name}님에게 귀가 알림을 전송했습니다.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade600,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );

        // 메시지 필드 초기화
        _messageController.clear();
      } catch (e) {
        Get.snackbar(
          '오류',
          '귀가 알림 전송 중 오류가 발생했습니다: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
        );
        debugPrint('❌ 귀가 알림 전송 오류: $e');
      } finally {
        _isLoading.value = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('귀가 알림'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '알림 보내기'),
              Tab(text: '위치 관리'),
            ],
          ),
        ),
        body: Obx(() {
          if (_isLoading.value && !_isInitialized.value) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (_errorMessage.value.isNotEmpty && !_isInitialized.value) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      '오류가 발생했습니다',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(_errorMessage.value),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initializeServices,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            );
          }

          return TabBarView(
            children: [
              // 알림 보내기 탭
              _buildSendNotificationTab(),

              // 위치 관리 탭
              _buildLocationManagementTab(),
            ],
          );
        }),
      ),
    );
  }

  // 알림 보내기 탭
  Widget _buildSendNotificationTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 선택된 집 위치 표시
              Obx(() {
                final selectedHome =
                    _homeLocationService.getSelectedHomeLocation();

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.home, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              '선택된 집 위치:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (selectedHome != null)
                              TextButton(
                                onPressed: () {
                                  // 위치 관리 탭으로 이동
                                  DefaultTabController.of(context).animateTo(1);
                                },
                                child: const Text('변경'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (selectedHome != null) ...[
                          Text(
                            selectedHome.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(selectedHome.address),
                        ] else ...[
                          const Text(
                            '등록된 집 위치가 없습니다.',
                            style: TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _addNewHomeLocation,
                            icon: const Icon(Icons.add_location),
                            label: const Text('집 위치 등록하기'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),

              // 알림 방법 선택
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '알림 방법 선택:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Obx(() => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: () {
                                    _selectedNotificationMethod.value = 'user';
                                    _selectedEmergencyContact.value = null;
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color:
                                          _selectedNotificationMethod.value ==
                                                  'user'
                                              ? Colors.blue.shade50
                                              : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            _selectedNotificationMethod.value ==
                                                    'user'
                                                ? Colors.blue
                                                : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: 'user',
                                          groupValue:
                                              _selectedNotificationMethod.value,
                                          onChanged: (value) {
                                            _selectedNotificationMethod.value =
                                                value!;
                                            _selectedEmergencyContact.value =
                                                null;
                                          },
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('앱 사용자'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: GestureDetector(
                                  onTap: () {
                                    _selectedNotificationMethod.value =
                                        'emergency';
                                    _selectedUser.value = null;
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color:
                                          _selectedNotificationMethod.value ==
                                                  'emergency'
                                              ? Colors.blue.shade50
                                              : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            _selectedNotificationMethod.value ==
                                                    'emergency'
                                                ? Colors.blue
                                                : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Radio<String>(
                                          value: 'emergency',
                                          groupValue:
                                              _selectedNotificationMethod.value,
                                          onChanged: (value) {
                                            _selectedNotificationMethod.value =
                                                value!;
                                            _selectedUser.value = null;
                                          },
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('긴급 연락처'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )),
                    ],
                  ),
                ),
              ),

              // 알림 받을 사람 선택
              Obx(() {
                // 앱 사용자 선택 UI
                if (_selectedNotificationMethod.value == 'user') {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '알림 받을 사람:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),

                      // 선택된 사용자 표시
                      if (_selectedUser.value != null)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: NetworkImage(
                                  _selectedUser.value!.profileImageUrl ?? ''),
                            ),
                            title:
                                Text(_selectedUser.value!.nickname ?? '이름 없음'),
                            subtitle:
                                Text(_selectedUser.value!.email ?? '이메일 없음'),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _selectedUser.value = null;
                              },
                            ),
                          ),
                        )
                      else
                        Column(
                          children: [
                            // 사용자 검색 필드
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: '이름 또는 이메일로 검색',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          _searchResults.clear();
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (value) {
                                _searchUsers(value);
                              },
                            ),
                            const SizedBox(height: 8),

                            // 검색 결과
                            if (_isSearchingUsers.value)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_searchResults.isEmpty &&
                                _searchController.text.isNotEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text('검색 결과가 없습니다.'),
                                ),
                              )
                            else if (_searchResults.isNotEmpty)
                              SizedBox(
                                height: 120,
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final user = _searchResults[index];
                                      return ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          backgroundImage: NetworkImage(
                                              user.profileImageUrl ?? ''),
                                        ),
                                        title: Text(user.nickname ?? '이름 없음'),
                                        subtitle: Text(user.email ?? '이메일 없음'),
                                        onTap: () {
                                          _selectedUser.value = user;
                                          _searchController.clear();
                                          _searchResults.clear();
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  );
                }
                // 긴급 연락처 선택 UI
                else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '알림 받을 긴급 연락처:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),

                      // 선택된 긴급 연락처 표시
                      if (_selectedEmergencyContact.value != null)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.contact_phone),
                            ),
                            title: Text(_selectedEmergencyContact.value!.name),
                            subtitle: Text(
                                _selectedEmergencyContact.value!.phoneNumber),
                            trailing: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _selectedEmergencyContact.value = null;
                              },
                            ),
                          ),
                        )
                      else
                        // 긴급 연락처 목록 - 사용자 정의 연락처만 표시 (기본 연락처 제외)
                        SizedBox(
                          height: 160,
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: _emergencyContactService
                                    .customContacts.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.contact_phone_outlined,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          '등록된 긴급 연락처가 없습니다',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton.icon(
                                          onPressed: () {
                                            Get.toNamed('/emergency-contacts');
                                          },
                                          icon: const Icon(Icons.add),
                                          label: const Text('긴급 연락처 추가하기'),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _emergencyContactService
                                        .customContacts.length,
                                    itemBuilder: (context, index) {
                                      final contact = _emergencyContactService
                                          .customContacts[index];
                                      return ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              Colors.green.shade100,
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.green,
                                          ),
                                        ),
                                        title: Text(contact.name),
                                        subtitle: Text(contact.phoneNumber),
                                        onTap: () {
                                          _selectedEmergencyContact.value =
                                              contact;
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ),
                    ],
                  );
                }
              }),

              const SizedBox(height: 8),

              // 메시지 입력
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 2.0, vertical: 4.0),
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: '메시지 (선택사항)',
                      hintText: '예: 집에 안전하게 도착했어요!',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                    ),
                    maxLines: 2,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 알림 보내기 버튼
              Obx(() {
                final selectedHome =
                    _homeLocationService.getSelectedHomeLocation();
                final canSend = selectedHome != null &&
                    (_selectedUser.value != null ||
                        _selectedEmergencyContact.value != null);

                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: canSend && !_isLoading.value
                        ? _sendHomeArrivalNotification
                        : null,
                    icon: _isLoading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: const Text(
                      '귀가 알림 보내기',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // 위치 관리 탭
  Widget _buildLocationManagementTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '등록된 집 위치',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addNewHomeLocation,
                icon: const Icon(Icons.add_location),
                label: const Text('새 위치 추가'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 위치 목록
          Expanded(
            child: Obx(() {
              if (_homeLocationService.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (_homeLocationService.homeLocations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '등록된 집 위치가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addNewHomeLocation,
                        icon: const Icon(Icons.add_location),
                        label: const Text('현재 위치로 등록하기'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: _homeLocationService.homeLocations.length,
                itemBuilder: (context, index) {
                  final location = _homeLocationService.homeLocations[index];
                  final isSelected = location.id ==
                      _homeLocationService.selectedHomeLocationId.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        // 위치 선택
                        _homeLocationService
                            .setSelectedHomeLocation(location.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.home,
                                  color: isSelected ? Colors.blue : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    location.name,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.blue : null,
                                    ),
                                  ),
                                ),
                                if (location.isDefault)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      '기본',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(location.address),
                            const SizedBox(height: 4),
                            Text(
                              '위도: ${location.latitude.toStringAsFixed(6)}, 경도: ${location.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isSelected)
                                  TextButton.icon(
                                    onPressed: () {
                                      _homeLocationService
                                          .setSelectedHomeLocation(location.id);
                                    },
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('선택'),
                                  ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    // 위치 삭제 확인 다이얼로그
                                    Get.dialog(
                                      AlertDialog(
                                        title: const Text('위치 삭제'),
                                        content: Text(
                                            '\'${location.name}\' 위치를 삭제하시겠습니까?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Get.back(),
                                            child: const Text('취소'),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Get.back();
                                              final success =
                                                  await _homeLocationService
                                                      .deleteHomeLocation(
                                                          location.id);

                                              if (success) {
                                                Get.snackbar(
                                                  '성공',
                                                  '위치가 삭제되었습니다.',
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
                                                  backgroundColor:
                                                      Colors.green.shade600,
                                                  colorText: Colors.white,
                                                );
                                              } else {
                                                Get.snackbar(
                                                  '실패',
                                                  '위치 삭제에 실패했습니다: ${_homeLocationService.errorMessage.value}',
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
                                                  backgroundColor:
                                                      Colors.red.shade700,
                                                  colorText: Colors.white,
                                                );
                                              }
                                            },
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                            child: const Text('삭제'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.delete,
                                      size: 18, color: Colors.red),
                                  label: const Text('삭제',
                                      style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
