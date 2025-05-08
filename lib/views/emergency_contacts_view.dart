// ****************************************************************************
// ******** 중요: 이 파일은 보호된 긴급 연락처 관련 코드입니다. 절대 수정하지 마세요. *******
// ****************************************************************************

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_contact_model.dart';
import '../services/emergency_contact_service.dart';

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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddContactDialog(context),
        child: const Icon(Icons.add),
        tooltip: '긴급 연락처 추가',
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
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final descriptionController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('긴급 연락처 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                Get.snackbar(
                  '오류',
                  '이름과 전화번호는 필수입니다.',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              final contact = EmergencyContact(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                phoneNumber: phoneController.text.trim(),
                description: descriptionController.text.trim(),
              );

              final service = Get.find<EmergencyContactService>();
              bool success = await service.addContact(contact);
              Get.back();

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
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  // 연락처 수정 다이얼로그
  void _showEditContactDialog(BuildContext context, EmergencyContact contact) {
    final nameController = TextEditingController(text: contact.name);
    final phoneController = TextEditingController();
    final descriptionController =
        TextEditingController(text: contact.description ?? '');

    Get.dialog(
      AlertDialog(
        title: const Text('긴급 연락처 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '이름 또는 기관명',
                ),
              ),
              const SizedBox(height: 16),
              _buildPhoneTextField(phoneController,
                  initialValue: contact.phoneNumber),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: '설명 (선택사항)',
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
              if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                Get.snackbar(
                  '오류',
                  '이름과 전화번호는 필수입니다.',
                  snackPosition: SnackPosition.BOTTOM,
                );
                return;
              }

              final updatedContact = contact.copyWith(
                name: nameController.text.trim(),
                phoneNumber: phoneController.text.trim(),
                description: descriptionController.text.trim(),
              );

              final service = Get.find<EmergencyContactService>();
              bool success = await service.updateContact(updatedContact);
              Get.back();

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
}
