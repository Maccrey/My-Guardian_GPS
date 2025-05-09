import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../services/emergency_contact_service.dart';

class SOSController extends GetxController {
  final RxBool isSOSActive = false.obs;
  final RxInt countdown = 10.obs; // 10초 카운트다운으로 수정
  Timer? _timer;

  // 기본 긴급 번호 리스트 (알림을 보내지 않을 번호들)
  final List<String> excludedNumbers = [
    '112',
    '122',
    '1301',
    '044-205-1542',
    '119',
    '044205-1542',
    '0442051542' // 하이픈 없는 형태도 추가
  ];

  // 고정된 긴급 연락처 제거

  void activateSOS() {
    isSOSActive.value = true;
    _startCountdown();
  }

  void cancelSOS() {
    isSOSActive.value = false;
    _stopCountdown();
    countdown.value = 10; // 카운트다운 리셋값 수정
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown.value > 0) {
        countdown.value--;
      } else {
        // 카운트다운 완료, SOS 동작 실행
        _executeSOSAction();
        cancelSOS(); // SOS 상태 초기화
      }
    });
  }

  void _stopCountdown() {
    _timer?.cancel();
  }

  Future<void> _executeSOSAction() async {
    // 긴급 연락처에 알림 전송 (실제 구현 시에는 FCM 또는 SMS 활용)
    await _sendEmergencyNotifications();

    // 119로 전화 걸기
    await callEmergencyNumber('119');
  }

  Future<void> _sendEmergencyNotifications() async {
    try {
      // EmergencyContactService에서 긴급 연락처 가져오기
      final emergencyContactService = Get.find<EmergencyContactService>();
      final allContacts = emergencyContactService.contacts;

      // 제외할 번호 목록에 없는 연락처만 필터링 (강화된 필터링)
      final filteredContacts = allContacts.where((contact) {
        // 번호에서 모든 하이픈, 공백 제거
        String cleanNumber =
            contact.phoneNumber.replaceAll(RegExp(r'[-\s]'), '').trim();

        // 제외 목록의 각 번호도 정리하여 비교
        for (var excluded in excludedNumbers) {
          String cleanExcluded =
              excluded.replaceAll(RegExp(r'[-\s]'), '').trim();
          if (cleanNumber == cleanExcluded) {
            return false; // 제외 목록에 있으면 필터링
          }
        }
        return true; // 제외 목록에 없으면 포함
      }).toList();

      // 실제 알림 전송 로직은 향후 구현
      // 현재는 로그 출력으로 대체
      debugPrint('⚠️ 긴급 알림 전송 중...');

      if (filteredContacts.isEmpty) {
        debugPrint('⚠️ 전송할 개인 긴급 연락처가 없습니다.');
        Get.snackbar(
          '알림 전송 실패',
          '전송할 개인 긴급 연락처가 없습니다. 설정 메뉴에서 긴급 연락처를 추가해주세요.',
          backgroundColor: Colors.yellow.shade100,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      for (var contact in filteredContacts) {
        debugPrint('  - ${contact.name}에게 알림 전송: ${contact.phoneNumber}');
      }

      // 알림 전송 성공 토스트 메시지
      Get.snackbar(
        '긴급 알림 전송',
        '개인 긴급 연락처로 SOS 알림이 전송되었습니다.',
        backgroundColor: Colors.red.shade100,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('⚠️ 긴급 알림 전송 실패: $e');
      Get.snackbar(
        '알림 전송 실패',
        '긴급 연락처로 알림을 전송하는데 실패했습니다.',
        backgroundColor: Colors.red.shade200,
        duration: const Duration(seconds: 3),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> callEmergencyNumber(String number) async {
    debugPrint('📞 긴급 전화 걸기 시도: $number');

    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    try {
      bool launched = await launchUrl(phoneUri);
      if (launched) {
        debugPrint('✅ 전화 걸기 성공: $number');
      } else {
        throw Exception('전화를 걸 수 없습니다: $phoneUri');
      }
    } catch (e) {
      debugPrint('⚠️ 전화 걸기 실패: $e');
      Get.snackbar(
        '전화 걸기 실패',
        '긴급 전화를 걸 수 없습니다. 직접 119로 전화해주세요.',
        backgroundColor: Colors.red.shade200,
        duration: const Duration(seconds: 5),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}

class SOSView extends StatelessWidget {
  const SOSView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // GetX 컨트롤러 초기화
    final controller = Get.put(SOSController());
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text('긴급 SOS'),
        backgroundColor: Colors.red,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 안내 텍스트
              const SizedBox(height: 20),
              const Text(
                '긴급 상황 시 SOS 버튼을 눌러주세요',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                '버튼을 누르면 10초 후 자동으로 개인 긴급 연락처에 알림이 전송되고 119로 연결됩니다.',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // SOS 버튼 및 카운트다운 표시
              Expanded(
                child: Center(
                  child: Obx(() {
                    if (controller.isSOSActive.value) {
                      // SOS 활성화 상태 - 카운트다운 표시
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${controller.countdown.value}',
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '초 후 자동으로 개인 긴급 연락처에 알림이 전송됩니다',
                            style: TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: controller.cancelSOS,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: BorderSide(
                                    color: Colors.red.shade700, width: 2),
                              ),
                            ),
                            child: const Text(
                              'SOS 취소',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // 대기 상태 - SOS 버튼 표시
                      return GestureDetector(
                        onTap: controller.activateSOS,
                        child: Container(
                          width: screenSize.width * 0.6,
                          height: screenSize.width * 0.6,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.shade200,
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  }),
                ),
              ),

              // 하단 설명 및 주의사항
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '주의사항:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('• 실제 긴급 상황에만 사용해주세요'),
                    Text('• 등록된 개인 긴급 연락처에만 알림이 전송됩니다'),
                    Text('• 오작동 시 10초 내에 취소 버튼을 눌러주세요'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 직접 119 전화 버튼
              ElevatedButton.icon(
                onPressed: () => controller.callEmergencyNumber('119'),
                icon: const Icon(Icons.phone, size: 24),
                label: const Text('119 직접 전화하기',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
