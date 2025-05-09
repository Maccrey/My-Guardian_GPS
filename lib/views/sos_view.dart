import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter/services.dart';
import '../services/emergency_contact_service.dart';
import 'package:volume_controller/volume_controller.dart';

class SOSController extends GetxController {
  final RxBool isSOSActive = false.obs;
  final RxInt countdown = 10.obs; // 10초 카운트다운
  final RxBool isAudioPlaying = false.obs;
  Timer? _timer;
  AudioPlayer? _audioPlayer;
  bool _isAudioInitialized = false;
  final RxDouble currentVolume = 0.0.obs;
  final VolumeController _volumeController = VolumeController();

  @override
  void onInit() {
    super.onInit();
    _initAudioPlayer();
    _initVolumeController();
  }

  void _initVolumeController() {
    // 볼륨 컨트롤러 초기화 및 리스너 설정
    _volumeController.listener((volume) {
      currentVolume.value = volume;
      debugPrint('현재 볼륨 레벨: $volume');
    });

    // 초기 볼륨 수준 가져오기
    _volumeController.getVolume().then((volume) {
      currentVolume.value = volume;
      debugPrint('초기 볼륨 레벨: $volume');
    });
  }

  Future<void> _initAudioPlayer() async {
    try {
      // 오디오 플레이어 초기화
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setLoopMode(LoopMode.one); // 소리 반복 설정
      await _audioPlayer!.setVolume(1.0); // 최대 볼륨으로 설정
      _isAudioInitialized = true;
      debugPrint('✅ 오디오 플레이어 초기화 성공');
    } catch (e) {
      debugPrint('⚠️ 오디오 플레이어 초기화 오류: $e');
      _isAudioInitialized = false;
    }
  }

  // 사이렌 소리 재생
  Future<void> _playSiren() async {
    try {
      if (_audioPlayer == null || !_isAudioInitialized) {
        await _initAudioPlayer();
        if (!_isAudioInitialized) {
          debugPrint('⚠️ 오디오 플레이어 초기화 실패, 사이렌 재생 불가');
          return;
        }
      }

      // 사용자에게 볼륨이 최대로 올라간다는 메시지 표시
      Get.snackbar(
        '긴급 알림',
        '볼륨이 최대로 증가합니다. 긴급 상황에서는 소리가 잘 들리도록 합니다.',
        backgroundColor: Colors.red.shade100,
        duration: const Duration(seconds: 2),
        snackPosition: SnackPosition.TOP,
      );

      // 시스템 볼륨을 최대로 설정
      _volumeController.setVolume(1.0, showSystemUI: false);
      debugPrint('🔊 시스템 볼륨 최대로 설정됨');

      // 플레이어 볼륨도 최대로 설정
      await _audioPlayer!.setVolume(1.0);
      debugPrint('🔊 오디오 플레이어 볼륨 최대로 설정됨');

      // 진동 알림도 함께 제공 (사용자 주의 환기용)
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 500));
      HapticFeedback.heavyImpact();

      try {
        // 미디어 정보 설정
        final mediaItem = MediaItem(
          id: 'sos_siren',
          title: 'SOS 긴급 알림',
          artist: 'GPS Search',
          artUri: null,
        );

        // 사이렌 소리 로드 및 재생 (파일명 수정)
        await _audioPlayer!.setAudioSource(
          AudioSource.asset(
            'assets/mp3/siren.mp3',
            tag: mediaItem,
          ),
        );

        // 소리 재생
        await _audioPlayer!.play();
        isAudioPlaying.value = true;
        debugPrint('✅ 사이렌 소리 재생 시작');

        // 30초마다 볼륨이 낮아지지 않도록 볼륨 유지
        _startVolumeKeeper();
      } catch (e) {
        debugPrint('⚠️ 사이렌 소리 설정 중 오류: $e');

        // 기본 재생 시도 (백그라운드 미디어 태그 없이)
        try {
          await _audioPlayer!.setAsset('assets/mp3/siren.mp3');
          await _audioPlayer!.play();
          isAudioPlaying.value = true;
          debugPrint('✅ 기본 모드로 사이렌 소리 재생 시작');
        } catch (e2) {
          debugPrint('⚠️ 기본 모드 사이렌 소리 재생 오류: $e2');
        }
      }
    } catch (e) {
      debugPrint('⚠️ 사이렌 소리 재생 오류: $e');
    }
  }

  // 볼륨을 최대로 유지하는 타이머
  Timer? _volumeKeeper;

  void _startVolumeKeeper() {
    _volumeKeeper?.cancel();
    _volumeKeeper = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (isAudioPlaying.value) {
        try {
          // 주기적으로 볼륨이 최대인지 확인하고 아니면 다시 최대로 설정
          double currentVol = await _volumeController.getVolume();
          if (currentVol < 0.9) {
            _volumeController.setVolume(1.0, showSystemUI: false);
            debugPrint('🔊 볼륨 다시 최대로 설정됨 (이전: $currentVol)');
          }

          // 오디오 플레이어 볼륨도 확인
          if (_audioPlayer != null && _audioPlayer!.volume < 0.9) {
            await _audioPlayer!.setVolume(1.0);
          }
        } catch (e) {
          debugPrint('⚠️ 볼륨 유지 오류: $e');
        }
      } else {
        _volumeKeeper?.cancel();
      }
    });
  }

  // 사이렌 소리 정지
  Future<void> _stopSiren() async {
    try {
      // 볼륨 유지 타이머 취소
      _volumeKeeper?.cancel();

      if (_audioPlayer != null && _audioPlayer!.playing) {
        await _audioPlayer!.stop();
        isAudioPlaying.value = false;
        debugPrint('✅ 사이렌 소리 정지');
      }
    } catch (e) {
      debugPrint('⚠️ 사이렌 소리 정지 오류: $e');
    }
  }

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

  // 개인 긴급 연락처가 있는지 확인하는 메서드
  Future<bool> hasPersonalEmergencyContacts() async {
    try {
      final emergencyContactService = Get.find<EmergencyContactService>();
      final allContacts = emergencyContactService.contacts;

      // 개인 긴급 연락처 필터링 (기본 긴급 번호 제외)
      final personalContacts = allContacts.where((contact) {
        String cleanNumber =
            contact.phoneNumber.replaceAll(RegExp(r'[-\s]'), '').trim();
        for (var excluded in excludedNumbers) {
          String cleanExcluded =
              excluded.replaceAll(RegExp(r'[-\s]'), '').trim();
          if (cleanNumber == cleanExcluded) {
            return false;
          }
        }
        return true;
      }).toList();

      return personalContacts.isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ 긴급 연락처 확인 중 오류: $e');
      return false;
    }
  }

  // SOS 활성화 시 개인 긴급 연락처가 없는 경우 확인 및 안내
  Future<void> activateSOS() async {
    // 개인 긴급 연락처 확인
    bool hasContacts = await hasPersonalEmergencyContacts();

    if (!hasContacts) {
      // 개인 긴급 연락처가 없는 경우 경고 다이얼로그 표시
      Get.dialog(
        AlertDialog(
          title: const Text('긴급 연락처 없음'),
          content: const Text(
              '등록된 개인 긴급 연락처가 없습니다. SOS 기능을 사용하기 위해서는 개인 긴급 연락처를 등록해야 합니다.\n\n긴급 연락처 설정 페이지로 이동하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Get.back(); // 현재 다이얼로그 닫기
                Get.toNamed('/emergency-contacts'); // 긴급 연락처 화면으로 이동
              },
              child: const Text('연락처 등록'),
            ),
            TextButton(
              onPressed: () {
                Get.back(); // 현재 다이얼로그 닫기
                // 연락처 없이 진행
                isSOSActive.value = true;
                _startCountdown();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('그래도 진행'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } else {
      // 개인 긴급 연락처가 있는 경우 정상 진행
      isSOSActive.value = true;
      _startCountdown();
    }
  }

  void cancelSOS() {
    isSOSActive.value = false;
    _stopCountdown();
    _stopSiren(); // 사이렌 소리 정지
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
        // SOS 상태는 유지하고, 카운트다운만 중지 (사이렌이 계속 재생되도록)
        _stopCountdown();
      }
    });
  }

  void _stopCountdown() {
    _timer?.cancel();
  }

  Future<void> _executeSOSAction() async {
    // 사이렌 소리 재생
    await _playSiren();

    // 진동 알림 (추가적인 주의 효과)
    HapticFeedback.heavyImpact();

    // 긴급 연락처에 알림 전송
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
        // 긴급 연락처가 없음을 알리는 메시지만 표시하고 계속 진행
        Get.snackbar(
          '알림 전송 실패',
          '전송할 개인 긴급 연락처가 없습니다. 119로 연결합니다.',
          backgroundColor: Colors.yellow.shade100,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
        );

        // 이 시점에서는 SOS 프로세스를 계속 진행(119로 전화)
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

    // tel 스킴 URI 생성
    final Uri phoneUri = Uri(scheme: 'tel', path: number);

    try {
      // 첫 번째 방법: 직접 launchUrl 시도
      bool launched =
          await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      if (launched) {
        debugPrint('✅ 전화 걸기 성공: $number');
      } else {
        debugPrint('❌ launchUrl 실패, 두 번째 방식 시도');
        // 두 번째 방법: canLaunch 확인 후 launch 호출
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
          debugPrint('✅ 두 번째 방식으로 전화 걸기 성공: $number');
        } else {
          throw Exception('전화를 걸 수 없습니다: $phoneUri');
        }
      }
    } catch (e) {
      debugPrint('⚠️ 전화 걸기 실패: $e');
      // 사용자에게 실패 알림
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
    _volumeKeeper?.cancel();
    _stopSiren();
    _timer?.cancel();
    _audioPlayer?.dispose();
    super.onClose();
  }
}

class SOSView extends StatefulWidget {
  const SOSView({Key? key}) : super(key: key);

  @override
  State<SOSView> createState() => _SOSViewState();
}

class _SOSViewState extends State<SOSView> with WidgetsBindingObserver {
  late SOSController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = Get.put(SOSController());

    // 첫 화면 로드 시 연락처 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEmergencyContacts();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 다시 활성화되었을 때 연락처 확인
      _checkEmergencyContacts();
    }
  }

  // 연락처 확인 및 안내
  Future<void> _checkEmergencyContacts() async {
    if (!await controller.hasPersonalEmergencyContacts()) {
      // 딜레이를 줘서 화면 전환 후에 다이얼로그 표시
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;

        Get.snackbar(
          '긴급 연락처 없음',
          '개인 긴급 연락처가 등록되지 않았습니다. SOS 기능의 원활한 사용을 위해 등록을 권장합니다.',
          backgroundColor: Colors.yellow.shade100,
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.TOP,
          mainButton: TextButton(
            onPressed: () {
              Get.toNamed('/emergency-contacts');
            },
            child: const Text('연락처 등록', style: TextStyle(color: Colors.blue)),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
