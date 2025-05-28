// ****************************************************************************
// ******** 중요: 이 파일은 보호된 긴급 연락처 관련 코드입니다. 절대 수정하지 마세요. *******
// ****************************************************************************

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../models/emergency_contact_model.dart';
import '../../services/emergency_contact_service.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../location_sharing/location_sharing_button.dart';

class EmergencyContactsView extends StatefulWidget {
  const EmergencyContactsView({Key? key}) : super(key: key);

  @override
  State<EmergencyContactsView> createState() => _EmergencyContactsViewState();
}

class _EmergencyContactsViewState extends State<EmergencyContactsView>
    with WidgetsBindingObserver {
  late final EmergencyContactService emergencyContactService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    emergencyContactService = Get.find<EmergencyContactService>();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 다시 활성화되었을 때 연락처 새로고침
      emergencyContactService.loadContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('긴급 연락처'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          // 저장 상태 아이콘 표시
          Obx(() {
            if (emergencyContactService.isLoading.value) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            } else if (emergencyContactService.hasError.value) {
              return IconButton(
                icon: const Icon(Icons.error_outline, color: Colors.red),
                onPressed: () {
                  Get.snackbar(
                    '저장 오류',
                    '연락처 저장 중 문제가 발생했습니다. 다시 시도해주세요.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red.shade100,
                    colorText: Colors.black87,
                    mainButton: TextButton(
                      onPressed: () {
                        // 현재 메모리의 연락처를 다시 저장
                        emergencyContactService.saveContacts(
                          emergencyContactService.contacts,
                        );
                      },
                      child: const Text('재시도'),
                    ),
                  );
                },
              );
            } else {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  emergencyContactService.loadContacts();
                },
              );
            }
          }),
        ],
      ),
      body: Obx(() {
        if (emergencyContactService.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // 오류 상태 확인 및 표시
        if (emergencyContactService.hasError.value) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 64, color: Colors.orange),
                  SizedBox(height: 16),
                  Text(
                    '데이터 로드 중 오류가 발생했습니다.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '현재 메모리 모드로 작동 중입니다. 연락처 변경 사항이 저장되지 않을 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: Icon(Icons.refresh),
                    label: Text('다시 시도'),
                    onPressed: () => emergencyContactService.loadContacts(),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          children: [
            _buildHeader(),
            _buildContactGroup(
              context,
              title: '기본 긴급 연락처',
              icon: Icons.call,
              contacts: emergencyContactService.defaultContacts,
              isDefault: true,
            ),
            _buildContactGroup(
              context,
              title: '내 긴급 연락처',
              icon: Icons.contact_phone,
              contacts: emergencyContactService.customContacts,
              isDefault: false,
            ),
            const SizedBox(height: 80),
          ],
        );
      }),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 기존 연락처 추가 버튼
          FloatingActionButton(
            heroTag: 'addContact',
            onPressed: () => _showAddContactDialog(context),
            child: const Icon(Icons.add),
            tooltip: '긴급 연락처 추가',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ---------------------------------------------------------
  // ****** 보호된 코드: 헤더 렌더링 - 수정하지 마세요 ******
  // ---------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.contact_phone,
            size: 60,
            color: Colors.blue,
          ),
          SizedBox(height: 16),
          Text(
            '긴급 연락처',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '긴급 상황 시 필요한 연락처들을 저장하고 관리하세요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // ****** 보호된 코드: 연락처 그룹 렌더링 - 수정하지 마세요 ******
  // ---------------------------------------------------------
  Widget _buildContactGroup(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<EmergencyContact> contacts,
    required bool isDefault,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (contacts.isEmpty && !isDefault)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '등록된 연락처가 없습니다.\n오른쪽 하단의 + 버튼을 눌러 연락처를 추가하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ...contacts.map((contact) => _buildContactTile(context, contact)),
        const Divider(),
      ],
    );
  }

  Widget _buildContactTile(BuildContext context, EmergencyContact contact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          leading: CircleAvatar(
            backgroundColor: contact.isDefault ? Colors.blue : Colors.teal,
            child: Icon(
              contact.isDefault ? Icons.call : Icons.person,
              color: Colors.white,
            ),
          ),
          title: Text(contact.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.phoneNumber),
              if (contact.description != null &&
                  contact.description!.isNotEmpty)
                Text(
                  contact.description!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
          trailing: !contact.isDefault
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: () => _makePhoneCall(contact.phoneNumber),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditContactDialog(context, contact),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _showDeleteContactDialog(context, contact),
                      padding: const EdgeInsets.all(8.0),
                    ),
                  ],
                )
              : IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _makePhoneCall(contact.phoneNumber),
                ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // ****** 보호된 코드: 연락처 액션 함수 - 수정하지 마세요 ******
  // ---------------------------------------------------------
  Future<void> _makePhoneCall(String phoneNumber) async {
    // 하이픈 제거
    final cleanNumber = phoneNumber.replaceAll('-', '');
    // tel Uri 대신 DIAL 액션으로 변경 (전화 걸기 화면만 표시)
    final Uri uri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      debugPrint('📞 전화 걸기 화면 표시: $cleanNumber');

      // 전화 앱 실행 (통화 화면만 보여주고 바로 걸지는 않음)
      await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
    } catch (e) {
      debugPrint('❌ 전화 걸기 화면 표시 오류: $e');

      Get.snackbar(
        '전화 앱 실행 실패',
        '전화 앱을 실행할 수 없습니다. 직접 $phoneNumber 번호로 전화해 주세요.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.black87,
      );
    }
  }

  // 전화번호 입력 필드
  Widget _buildPhoneTextField(TextEditingController controller,
      {String? initialValue}) {
    if (initialValue != null) {
      controller.text = initialValue;
    }

    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        labelText: '전화번호',
        hintText: '예: 01012345678 (하이픈은 자동 추가됩니다)',
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly, // 숫자만 입력 가능
        LengthLimitingTextInputFormatter(13), // 최대 13자 제한 (하이픈 포함)
      ],
      onChanged: (value) {
        // 숫자만 남기기
        final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

        // 전화번호 형식에 맞게 하이픈 추가
        String formatted = '';

        if (digitsOnly.length <= 3) {
          formatted = digitsOnly;
        } else if (digitsOnly.length <= 7) {
          // 앞 3자리 + 나머지
          formatted =
              '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3)}';
        } else if (digitsOnly.length <= 11) {
          // 앞 3자리 + 중간 4자리 + 나머지
          formatted =
              '${digitsOnly.substring(0, 3)}-${digitsOnly.substring(3, 7)}-${digitsOnly.substring(7)}';
        }

        // 변경된 경우에만 업데이트 (무한 루프 방지)
        if (formatted != value) {
          controller.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
      },
    );
  }

  // 연락처 추가 다이얼로그
  void _showAddContactDialog(BuildContext context) {
    _showContactAddForm(context);
  }

  // 긴급 연락처 추가 폼 다이얼로그
  void _showContactAddForm(
    BuildContext context, {
    TextEditingController? nameCtrl,
    TextEditingController? phoneCtrl,
    TextEditingController? descCtrl,
    TextEditingController? searchCtrl,
    List<UserModel>? results,
    bool? searching,
    bool? appUserMode,
    UserModel? selected,
    bool? isLocationSharingEnabled,
  }) {
    final nameController = nameCtrl ?? TextEditingController();
    final phoneController = phoneCtrl ?? TextEditingController();
    final descriptionController = descCtrl ?? TextEditingController();
    final searchController = searchCtrl ?? TextEditingController();
    final searchResults = results ?? <UserModel>[];
    final isSearching = searching ?? false;
    final selectedUser = selected;
    final canShareLocation = isLocationSharingEnabled ?? false;

    Get.dialog(
      AlertDialog(
        title: Text('긴급 연락처 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 기본 연락처 정보 입력 필드
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '이름 또는 기관명',
                  hintText: '예: 홍길동, 가까운 병원',
                ),
              ),
              const SizedBox(height: 16),
              _buildPhoneTextField(phoneController),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '설명 (선택사항)',
                  hintText: '예: 가족, 주치의, 가까운 병원',
                ),
              ),
              const SizedBox(height: 24),

              // 구분선
              Divider(color: Colors.grey.shade300),

              // 앱 사용자 검색 섹션
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '앱 사용자 검색',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '앱 사용자 검색으로 위치를 공유할 수 있는 연락처를 추가합니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 앱 사용자 검색 버튼
                    InkWell(
                      onTap: () {
                        // 검색 다이얼로그 표시
                        _showUserSearchDialog(
                          context,
                          searchController,
                          nameController,
                          phoneController,
                          descriptionController,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedUser != null
                                    ? '${selectedUser.displayName} (${selectedUser.email})'
                                    : '앱 사용자 검색하기',
                                style: TextStyle(
                                  color: selectedUser != null
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            if (selectedUser != null)
                              IconButton(
                                icon: Icon(Icons.close, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                onPressed: () {
                                  Get.back();
                                  _showContactAddForm(
                                    context,
                                    nameCtrl: nameController,
                                    phoneCtrl: phoneController,
                                    descCtrl: descriptionController,
                                    searchCtrl: searchController,
                                    isLocationSharingEnabled: canShareLocation,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    // 위치 공유 옵션 (앱 사용자가 선택된 경우만 표시)
                    if (selectedUser != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: canShareLocation,
                              onChanged: (value) {
                                Get.back();
                                _showContactAddForm(
                                  context,
                                  nameCtrl: nameController,
                                  phoneCtrl: phoneController,
                                  descCtrl: descriptionController,
                                  searchCtrl: searchController,
                                  selected: selectedUser,
                                  isLocationSharingEnabled: value ?? false,
                                );
                              },
                            ),
                            Expanded(
                              child: Text(
                                '위치 공유 활성화',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                            Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 18,
                            ),
                          ],
                        ),
                      ),

                    if (selectedUser != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 32.0),
                        child: Text(
                          '이 연락처와 실시간 위치를 공유할 수 있습니다',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              // 이름과 전화번호 필수
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                Get.snackbar(
                  '오류',
                  '이름과 전화번호는 필수입니다.',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              final service = Get.find<EmergencyContactService>();
              bool success = false;

              try {
                if (selectedUser != null) {
                  // 앱 사용자를 긴급 연락처로 추가
                  final contact = EmergencyContact.fromAppUser(
                    userId: selectedUser.uid,
                    name: nameController.text.trim(),
                    email: selectedUser.email,
                    phoneNumber: phoneController.text.trim(),
                    relationship: canShareLocation
                        ? '앱 사용자 (위치 공유 가능)'
                        : descriptionController.text.trim(),
                  );
                  success = await service.addContact(contact);
                } else {
                  // 일반 연락처 추가
                  final contact = EmergencyContact(
                    id: const Uuid().v4(),
                    name: nameController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    description: descriptionController.text.trim(),
                  );
                  success = await service.addContact(contact);
                }

                // 확실하게 다이얼로그 닫기 (중첩된 다이얼로그가 있을 수 있으므로)
                Navigator.of(context).pop();

                // 혹시 모든 다이얼로그가 닫히지 않았을 경우를 대비해 GetX 라우터로 모든 다이얼로그 닫기 시도
                while (Get.isDialogOpen ?? false) {
                  Get.back();
                }

                // 성공 여부에 따라 메시지 표시
                if (success) {
                  Get.snackbar(
                    '성공',
                    '연락처가 추가되었습니다.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.shade100,
                    colorText: Colors.black87,
                    duration: const Duration(seconds: 2),
                  );
                }
              } catch (e) {
                // 오류 발생 시 다이얼로그 닫기 확인 후 오류 메시지 표시
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }

                // 혹시 모든 다이얼로그가 닫히지 않았을 경우를 대비해 GetX 라우터로 모든 다이얼로그 닫기 시도
                while (Get.isDialogOpen ?? false) {
                  Get.back();
                }

                Get.snackbar(
                  '오류',
                  '연락처 추가 중 오류가 발생했습니다: $e',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.shade100,
                  colorText: Colors.black87,
                  duration: const Duration(seconds: 3),
                );
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // 사용자 검색 다이얼로그
  void _showUserSearchDialog(
    BuildContext context,
    TextEditingController searchController,
    TextEditingController nameController,
    TextEditingController phoneController,
    TextEditingController descriptionController,
  ) {
    List<UserModel> searchResults = [];
    bool isSearching = false;

    // 사용자 검색 함수
    void performSearch(String query) async {
      if (query.isEmpty) {
        searchResults = [];
        isSearching = false;
        return;
      }

      isSearching = true;
      Get.back(); // 이전 다이얼로그 닫기

      // 검색 중 다이얼로그 다시 표시
      Get.dialog(
        AlertDialog(
          title: Text('앱 사용자 검색'),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      try {
        final FirebaseFirestore firestore = FirebaseFirestore.instance;
        final AuthService authService = Get.find<AuthService>();

        // 이름, 이메일 또는 전화번호로 검색
        final nameQuery = await firestore
            .collection('users')
            .where('nickname', isGreaterThanOrEqualTo: query)
            .where('nickname', isLessThan: query + 'z')
            .get();

        final emailQuery = await firestore
            .collection('users')
            .where('email', isGreaterThanOrEqualTo: query)
            .where('email', isLessThan: query + 'z')
            .get();

        final phoneQuery = await firestore
            .collection('users')
            .where('phoneNumber', isGreaterThanOrEqualTo: query)
            .where('phoneNumber', isLessThan: query + 'z')
            .get();

        // 결과 병합 및 중복 제거
        final results = <UserModel>{};

        for (var doc in nameQuery.docs) {
          final user = UserModel.fromFirestore(doc);
          if (user.uid != authService.currentUser?.uid) {
            results.add(user);
          }
        }

        for (var doc in emailQuery.docs) {
          final user = UserModel.fromFirestore(doc);
          if (user.uid != authService.currentUser?.uid) {
            results.add(user);
          }
        }

        for (var doc in phoneQuery.docs) {
          final user = UserModel.fromFirestore(doc);
          if (user.uid != authService.currentUser?.uid) {
            results.add(user);
          }
        }

        searchResults = results.toList();
      } catch (e) {
        print('사용자 검색 오류: $e');
        Get.snackbar(
          '검색 오류',
          '사용자 검색 중 오류가 발생했습니다: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade100,
        );
      } finally {
        isSearching = false;
        Get.back(); // 검색 중 다이얼로그 닫기

        // 검색 결과 다이얼로그 표시
        _showSearchResultsDialog(
          context,
          searchController,
          searchResults,
          isSearching,
          nameController,
          phoneController,
          descriptionController,
          performSearch,
        );
      }
    }

    // 초기 검색 다이얼로그 표시
    _showSearchResultsDialog(
      context,
      searchController,
      searchResults,
      isSearching,
      nameController,
      phoneController,
      descriptionController,
      performSearch,
    );
  }

  // 검색 결과 다이얼로그
  void _showSearchResultsDialog(
    BuildContext context,
    TextEditingController searchController,
    List<UserModel> searchResults,
    bool isSearching,
    TextEditingController nameController,
    TextEditingController phoneController,
    TextEditingController descriptionController,
    Function(String) performSearch,
  ) {
    Get.dialog(
      AlertDialog(
        title: Text('앱 사용자 검색'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: Column(
            children: [
              // 검색 바
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: '이름, 이메일 또는 전화번호로 검색',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            Get.back();
                            _showSearchResultsDialog(
                              context,
                              searchController,
                              [],
                              false,
                              nameController,
                              phoneController,
                              descriptionController,
                              performSearch,
                            );
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  if (value.length >= 2) {
                    performSearch(value);
                  } else if (value.isEmpty) {
                    Get.back();
                    _showSearchResultsDialog(
                      context,
                      searchController,
                      [],
                      false,
                      nameController,
                      phoneController,
                      descriptionController,
                      performSearch,
                    );
                  }
                },
              ),
              SizedBox(height: 16),

              // 검색 상태 표시
              if (isSearching)
                Center(child: CircularProgressIndicator())
              else if (searchResults.isEmpty && searchController.text.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '이름, 이메일 또는 전화번호로\n앱 사용자를 검색하세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (searchResults.isEmpty &&
                  searchController.text.isNotEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '검색 결과가 없습니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '다른 검색어로 다시 시도해보세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchResults[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(user.displayName?.substring(0, 1) ?? '?'),
                        ),
                        title: Text(user.displayName ?? '이름 없음'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (user.email != null && user.email!.isNotEmpty)
                              Text(user.email!),
                            if (user.phoneNumber != null &&
                                user.phoneNumber!.isNotEmpty)
                              Text(user.phoneNumber!),
                          ],
                        ),
                        onTap: () {
                          // 선택한 사용자 정보 설정
                          Get.back();
                          _showContactAddForm(
                            context,
                            nameCtrl: nameController
                              ..text = user.displayName ?? '이름 없음',
                            phoneCtrl: phoneController
                              ..text = user.phoneNumber ?? '',
                            descCtrl: descriptionController
                              ..text = user.email ?? '',
                            searchCtrl: searchController,
                            appUserMode: true,
                            selected: user,
                          );
                        },
                        isThreeLine:
                            user.email != null && user.phoneNumber != null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _showContactAddForm(
                context,
                nameCtrl: nameController,
                phoneCtrl: phoneController,
                descCtrl: descriptionController,
                searchCtrl: searchController,
                appUserMode: true,
              );
            },
            child: Text('취소'),
          ),
        ],
      ),
    );
  }

  // 연락처 수정 다이얼로그
  void _showEditContactDialog(BuildContext context, EmergencyContact contact) {
    // 디버그: 현재 연락처 정보 로깅
    print(
        '수정 시작 - 연락처 정보: isAppUser=${contact.isAppUser}, relationship=${contact.relationship}, description=${contact.description}');

    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController(text: contact.phoneNumber);
    final descriptionController = TextEditingController(
      text: contact.isAppUser ? '' : contact.description ?? '',
    );
    final searchController = TextEditingController();

    // 위치 공유 활성화 여부 확인 - 로직 개선
    bool canShareLocation = false;
    if (contact.isAppUser) {
      canShareLocation = contact.relationship?.contains('위치 공유 가능') ?? false;
      print('위치 공유 상태 확인: ${contact.relationship} -> $canShareLocation');
    }

    // 앱 사용자인 경우 사용자 정보 가져오기
    if (contact.isAppUser && contact.userId != null) {
      // 로딩 다이얼로그 표시
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      FirebaseFirestore.instance
          .collection('users')
          .doc(contact.userId)
          .get()
          .then((doc) {
        // 로딩 다이얼로그 닫기
        Get.back();

        UserModel? selectedUser;
        if (doc.exists) {
          selectedUser = UserModel.fromFirestore(doc);
        }

        // 연락처 수정 폼 표시
        _showContactEditForm(
          context,
          contact,
          nameController: nameController,
          phoneController: phoneController,
          descController: descriptionController,
          searchController: searchController,
          isLocationSharingEnabled: canShareLocation,
          selectedUser: selectedUser,
        );
      }).catchError((e) {
        // 로딩 다이얼로그 닫기
        Get.back();

        print('사용자 정보 가져오기 오류: $e');
        // 오류가 있어도 수정 폼은 표시
        _showContactEditForm(
          context,
          contact,
          nameController: nameController,
          phoneController: phoneController,
          descController: descriptionController,
          searchController: searchController,
          isLocationSharingEnabled: canShareLocation,
        );
      });
    } else {
      // 일반 연락처인 경우 바로 수정 폼 표시
      _showContactEditForm(
        context,
        contact,
        nameController: nameController,
        phoneController: phoneController,
        descController: descriptionController,
        searchController: searchController,
        isLocationSharingEnabled: canShareLocation,
      );
    }
  }

  // 긴급 연락처 수정 폼 다이얼로그
  void _showContactEditForm(
    BuildContext context,
    EmergencyContact contact, {
    required TextEditingController nameController,
    required TextEditingController phoneController,
    required TextEditingController descController,
    required TextEditingController searchController,
    bool isLocationSharingEnabled = false,
    UserModel? selectedUser,
  }) {
    // 디버그: 수정 폼 초기 상태 로깅
    print('수정 폼 표시 - 위치 공유 활성화: $isLocationSharingEnabled');

    // 위치 공유 상태를 RxBool로 변환하여 상태 변화를 감지
    final RxBool canShareLocation = isLocationSharingEnabled.obs;

    Get.dialog(
      AlertDialog(
        title: Text('긴급 연락처 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 기본 연락처 정보 입력 필드
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '이름 또는 기관명',
                  hintText: '예: 홍길동, 가까운 병원',
                ),
              ),
              const SizedBox(height: 16),
              _buildPhoneTextField(phoneController),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: '설명 (선택사항)',
                  hintText: '예: 가족, 주치의, 가까운 병원',
                ),
              ),
              const SizedBox(height: 24),

              // 앱 사용자인 경우 추가 정보 표시
              if (contact.isAppUser)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 구분선
                    Divider(color: Colors.grey.shade300),

                    // 앱 사용자 정보
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '앱 사용자 정보',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '이 연락처는 앱 사용자로 실시간 위치 공유가 가능합니다',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 위치 공유 옵션 - Obx로 감싸서 상태 변화 감지
                          Obx(() => Row(
                                children: [
                                  Checkbox(
                                    value: canShareLocation.value,
                                    onChanged: (value) {
                                      // 상태 업데이트
                                      canShareLocation.value = value ?? false;
                                      print(
                                          '체크박스 상태 변경: ${canShareLocation.value}');
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      '위치 공유 활성화',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Icon(
                                    Icons.location_on,
                                    color: canShareLocation.value
                                        ? Colors.blue
                                        : Colors.grey,
                                    size: 18,
                                  ),
                                ],
                              )),

                          Padding(
                            padding: const EdgeInsets.only(left: 32.0),
                            child: Text(
                              '이 연락처와 실시간 위치를 공유할 수 있습니다',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),

                          // 위치 공유 상태에 따른 추가 안내
                          Obx(() => canShareLocation.value
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                      top: 8.0, left: 32.0),
                                  child: Text(
                                    '✓ 이 연락처는 위치 공유가 활성화됩니다',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : SizedBox.shrink()),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('취소 버튼 클릭 - 모든 다이얼로그 닫기 시도');

              // 현재 다이얼로그 닫기
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }

              // 모든 GetX 다이얼로그 닫기
              while (Get.isDialogOpen ?? false) {
                Get.back();
              }

              // 추가 안전 장치: 2초 후 다시 확인
              Future.delayed(const Duration(seconds: 2), () {
                if (Get.isDialogOpen ?? false) {
                  print('취소 후 2초 경과 - 열린 다이얼로그 추가 닫기');
                  Get.back(closeOverlays: true);
                }
              });
            },
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              // 이름과 전화번호 필수
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                Get.snackbar(
                  '오류',
                  '이름과 전화번호는 필수입니다.',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              try {
                // 디버그 메시지 추가
                print(
                    '연락처 업데이트 시작 - 앱 사용자: ${contact.isAppUser}, 위치 공유: ${canShareLocation.value}');

                // 연락처 업데이트
                EmergencyContact updatedContact;

                if (contact.isAppUser) {
                  String newRelationship;
                  if (canShareLocation.value) {
                    newRelationship = '앱 사용자 (위치 공유 가능)';
                  } else {
                    newRelationship = '앱 사용자';
                  }

                  updatedContact = contact.copyWith(
                    name: nameController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    relationship: newRelationship,
                  );
                } else {
                  updatedContact = contact.copyWith(
                    name: nameController.text.trim(),
                    phoneNumber: phoneController.text.trim(),
                    description: descController.text.trim(),
                  );
                }

                // 디버그 메시지 추가
                print(
                    '업데이트된 연락처 - 이름: ${updatedContact.name}, 관계: ${updatedContact.relationship}, 설명: ${updatedContact.description}');

                final service = Get.find<EmergencyContactService>();
                bool success = await service.updateContact(updatedContact);

                // 서비스의 연락처 리스트 갱신
                await service.loadContacts();

                // 확실하게 다이얼로그 닫기
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }

                // 혹시 모든 다이얼로그가 닫히지 않았을 경우를 대비
                while (Get.isDialogOpen ?? false) {
                  Get.back();
                }

                // 성공 여부에 따라 메시지 표시
                if (success) {
                  Get.snackbar(
                    '성공',
                    '연락처가 수정되었습니다.',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green.shade100,
                    colorText: Colors.black87,
                    duration: const Duration(seconds: 2),
                  );
                }
              } catch (e) {
                print('연락처 수정 오류: $e');

                // 오류 발생 시 다이얼로그 닫기 확인 후 오류 메시지 표시
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }

                // 혹시 모든 다이얼로그가 닫히지 않았을 경우를 대비
                while (Get.isDialogOpen ?? false) {
                  Get.back();
                }

                Get.snackbar(
                  '오류',
                  '연락처 수정 중 오류가 발생했습니다: $e',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.shade100,
                  colorText: Colors.black87,
                  duration: const Duration(seconds: 3),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // 연락처 삭제 다이얼로그
  void _showDeleteContactDialog(
      BuildContext context, EmergencyContact contact) {
    Get.dialog(
      AlertDialog(
        title: const Text('긴급 연락처 삭제'),
        content: Text('정말로 ${contact.name}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final service = Get.find<EmergencyContactService>();
              bool success = await service.deleteContact(contact.id);
              Get.back();

              // 성공 여부에 따라 메시지 표시
              if (success) {
                Get.snackbar(
                  '성공',
                  '연락처가 삭제되었습니다.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.shade100,
                  colorText: Colors.black87,
                  duration: const Duration(seconds: 2),
                );
              }
            },
            child: const Text('삭제'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  // 연락처 상세 정보 바텀 시트
  void _showContactDetailBottomSheet(
      BuildContext context, EmergencyContact contact) {
    // 디버그: 연락처 정보 로깅
    print(
        '연락처 상세 - ID: ${contact.id}, 이름: ${contact.name}, 앱 사용자: ${contact.isAppUser}, 관계: ${contact.relationship}');

    // 위치 공유 버튼 가져오기
    Widget locationSharingButton = const SizedBox.shrink();
    if (contact.isAppUser && contact.userId != null) {
      try {
        // 위치 공유 버튼 위젯 사용
        locationSharingButton = Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: LocationSharingButton(
            contactId: contact.userId!,
            contactName: contact.name,
            isAppUser: contact.isAppUser,
          ),
        );
        print('✅ 위치 공유 버튼 생성 성공: userId=${contact.userId}');
      } catch (e) {
        print('⚠️ 위치 공유 버튼 생성 오류: $e');
      }
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 연락처 프로필 헤더
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: Icon(
                    contact.isAppUser ? Icons.person : Icons.phone,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: Text(
                  contact.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  contact.relationship ?? (contact.description ?? ''),
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 구분선
              Divider(color: Colors.grey[300]),

              // 연락처 정보
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('전화번호'),
                subtitle: Text(contact.phoneNumber),
                trailing: IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () => _callPhone(contact.phoneNumber),
                ),
              ),

              // 추가 정보 (있는 경우)
              if (contact.description != null &&
                  contact.description!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('설명'),
                  subtitle: Text(contact.description!),
                ),

              // 위치 공유 버튼 (앱 사용자인 경우)
              locationSharingButton,

              const SizedBox(height: 16),

              // 연락처 관리 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 수정 버튼
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditContactDialog(context, contact);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('수정'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),

                  // 삭제 버튼
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showDeleteContactDialog(context, contact);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('삭제'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 전화 걸기 기능
  Future<void> _callPhone(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        Get.snackbar(
          '전화 오류',
          '전화를 걸 수 없습니다.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      print('전화 걸기 오류: $e');
      Get.snackbar(
        '전화 오류',
        '전화를 걸 수 없습니다: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
