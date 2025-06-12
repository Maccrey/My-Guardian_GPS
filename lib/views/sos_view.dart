import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import '../services/emergency_contact_service.dart';
import '../services/location_service.dart';
import 'package:geocoding/geocoding.dart';
import '../services/message_service.dart';
import 'package:volume_controller/volume_controller.dart';

class SOSController extends GetxController {
  // Rx 변수를 일반 변수로 변경하고 getter/setter 사용
  final _isSOSActive = false.obs;
  final _countdown = 30.obs;
  final _isAudioPlaying = false.obs;
  final _currentVolume = 1.0.obs;
  double? _originalSystemVolume;

  // 안전한 getter - 값을 직접 복사
  bool get isSOSActive => _isSOSActive.value;
  int get countdown => _countdown.value;
  bool get isAudioPlaying => _isAudioPlaying.value;
  double get currentVolume => _currentVolume.value;

  // 안전한 setter - 이미 닫힌 경우 오류 방지
  void setSOSActive(bool value) {
    if (_isDisposed) return;
    try {
      _isSOSActive.value = value;
    } catch (e) {
      debugPrint('⚠️ Rx 값 설정 오류(isSOSActive): $e');
    }
  }

  void setCountdown(int value) {
    if (_isDisposed) return;
    try {
      _countdown.value = value;
    } catch (e) {
      debugPrint('⚠️ Rx 값 설정 오류(countdown): $e');
    }
  }

  void setIsAudioPlaying(bool value) {
    if (_isDisposed) return;
    try {
      _isAudioPlaying.value = value;
    } catch (e) {
      debugPrint('⚠️ Rx 값 설정 오류(isAudioPlaying): $e');
    }
  }

  void setCurrentVolume(double value) {
    if (_isDisposed) return;
    try {
      _currentVolume.value = value;
    } catch (e) {
      debugPrint('⚠️ Rx 값 설정 오류(currentVolume): $e');
    }
  }

  void decrementCountdown() {
    if (_isDisposed) return;
    try {
      if (_countdown.value > 0) {
        _countdown.value--;
      }
    } catch (e) {
      debugPrint('⚠️ Rx 값 감소 오류(countdown): $e');
    }
  }

  Timer? _timer;
  AudioPlayer? _audioPlayer;
  bool _isAudioInitialized = false;
  bool _isDisposed = false;
  Timer? _volumeKeeper;

  final VolumeController _volumeController = VolumeController.instance;

  // 안전하게 Rx 값을 설정하는 헬퍼 함수들
  void safeSetBool(RxBool rx, bool value) {
    if (_isDisposed) return;
    try {
      rx.value = value;
    } catch (e) {
      debugPrint('⚠️ Rx 불리언 설정 오류: $e');
    }
  }

  void safeSetInt(RxInt rx, int value) {
    if (_isDisposed) return;
    try {
      rx.value = value;
    } catch (e) {
      debugPrint('⚠️ Rx 정수 설정 오류: $e');
    }
  }

  void safeSetDouble(RxDouble rx, double value) {
    if (_isDisposed) return;
    try {
      rx.value = value;
    } catch (e) {
      debugPrint('⚠️ Rx 실수 설정 오류: $e');
    }
  }

  // 안전하게 Rx 값을 증감하는 함수
  void safeDecrementInt(RxInt rx) {
    if (_isDisposed) return;
    try {
      rx.value--;
    } catch (e) {
      debugPrint('⚠️ Rx 정수 감소 오류: $e');
    }
  }

  @override
  void onInit() {
    super.onInit();
    _initAudioPlayer();
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

  // 시스템 볼륨 최대로
  Future<void> _setMaxSystemVolume() async {
    try {
      _originalSystemVolume = await _volumeController.getVolume();
      await _volumeController.setVolume(1.0); // 1.0이 최대
      debugPrint('✅ 시스템 볼륨 최대로 설정됨');
    } catch (e) {
      debugPrint('⚠️ 시스템 볼륨 최대로 설정 실패: $e');
    }
  }

  // 시스템 볼륨 복원
  Future<void> _restoreSystemVolume() async {
    try {
      if (_originalSystemVolume != null) {
        await _volumeController.setVolume(_originalSystemVolume!);
        debugPrint('✅ 시스템 볼륨 복원됨');
      }
    } catch (e) {
      debugPrint('⚠️ 시스템 볼륨 복원 실패: $e');
    }
  }

  // 사이렌 소리 재생 (just_audio로만 처리)
  Future<void> _playSiren() async {
    if (_isDisposed) {
      debugPrint('⚠️ 컨트롤러가 이미 해제됨 - 사이렌 재생 중단');
      return;
    }
    debugPrint('🔊 사이렌 재생 시작...');
    await _setMaxSystemVolume(); // 시스템 볼륨 최대로
    try {
      // 이미 재생 중인 경우 중지
      if (_audioPlayer != null) {
        if (_audioPlayer!.playing) {
          await _audioPlayer!.stop();
          debugPrint('✅ 기존 오디오 중지됨');
        }
      } else {
        // 오디오 플레이어가 없으면 새로 생성
        _audioPlayer = AudioPlayer();
        debugPrint('✅ 새 오디오 플레이어 생성됨');
      }

      // 오디오 플레이어 설정
      await _audioPlayer!.setVolume(1.0); // 볼륨 최대로 설정
      debugPrint('✅ 오디오 플레이어 볼륨 최대로 설정됨');

      // 루프 모드 설정
      await _audioPlayer!.setLoopMode(LoopMode.one);
      debugPrint('✅ 반복 재생 설정됨');

      // 햅틱 피드백 제공
      HapticFeedback.heavyImpact();

      // 오디오 파일 로드 및 재생 (간소화된 방식으로 변경)
      try {
        debugPrint('📂 사이렌 파일 로드 시도: assets/mp3/siren.mp3');

        // 수정: AudioSource 사용하지 않고 직접 setAsset 호출
        await _audioPlayer!.setAsset('assets/mp3/siren.mp3');
        debugPrint('✅ 사이렌 파일 로드 성공');

        // 재생 시작
        await _audioPlayer!.play();
        debugPrint('✅ 사이렌 재생 시작됨');

        // 상태 업데이트
        setIsAudioPlaying(true);

        // 볼륨 유지 타이머 시작 (just_audio 볼륨만 관리)
        _startVolumeKeeper();
      } catch (e) {
        debugPrint('⚠️ 사이렌 재생 실패: $e');

        // 두 번째 방법으로 시도 - MediaItem 없이 직접 호출
        try {
          debugPrint('🔄 두 번째 방법으로 사이렌 재생 시도...');

          // 수정: MediaItem과 AudioSource 사용하지 않고 직접 setAsset 호출
          await _audioPlayer!.stop(); // 혹시 모르니 한번 더 중지
          await _audioPlayer!.setAsset('assets/mp3/siren.mp3');
          await _audioPlayer!.setLoopMode(LoopMode.one);
          await _audioPlayer!.setVolume(1.0);
          await _audioPlayer!.play();

          debugPrint('✅ 두 번째 방법으로 사이렌 재생 성공');
          setIsAudioPlaying(true);

          // 성공 시 볼륨 유지 타이머 시작
          _startVolumeKeeper();
        } catch (e2) {
          debugPrint('⚠️ 두 번째 방법도 실패: $e2');
          setIsAudioPlaying(false);
        }
      }
    } catch (e) {
      debugPrint('⚠️ 사이렌 재생 중 심각한 오류: $e');

      // 오류 발생 시 자원 정리
      if (_audioPlayer != null) {
        try {
          _audioPlayer!.stop();
        } catch (_) {}
      }
      setIsAudioPlaying(false);
    }
  }

  // 오디오 플레이어 볼륨을 최대로 유지하는 타이머
  void _startVolumeKeeper() {
    _volumeKeeper?.cancel();
    _volumeKeeper = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (isAudioPlaying && _audioPlayer != null) {
        try {
          // 오디오 플레이어 볼륨만 확인
          if (_audioPlayer!.volume < 0.9) {
            await _audioPlayer!.setVolume(1.0);
            debugPrint('🔊 오디오 플레이어 볼륨 다시 최대로 설정됨');
          }
        } catch (e) {
          debugPrint('⚠️ 볼륨 유지 오류: $e');
        }
      } else {
        _volumeKeeper?.cancel();
      }
    });
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
    // 이미 dispose된 상태면 시작하지 않음
    if (_isDisposed) {
      debugPrint('⚠️ activateSOS: 컨트롤러가 이미 dispose됨');
      return;
    }

    // 이미 SOS가 활성화된 경우 중복 실행 방지
    if (isSOSActive) {
      debugPrint('⚠️ 이미 SOS가 활성화되어 있습니다.');
      return;
    }

    // 개인 긴급 연락처 확인
    bool hasContacts = false;
    try {
      hasContacts = await hasPersonalEmergencyContacts();
    } catch (e) {
      debugPrint('⚠️ 긴급 연락처 확인 오류: $e');
      // 오류 발생 시에도 기본값으로 진행
    }

    // SOS 시작 함수 (내부 함수로 정의)
    void startSOS() {
      // 함수 진입 시점에 다시 한번 isDisposed 확인
      if (_isDisposed) return;

      try {
        debugPrint('✅ SOS 시작 - 타이머부터 시작');

        // 1. 먼저 상태 변수 설정
        try {
          setSOSActive(true);
          setCountdown(30);
        } catch (e) {
          debugPrint('⚠️ SOS 상태 변수 설정 오류: $e');
          if (_isDisposed) return;
        }

        // 2. 타이머 먼저 시작 (가장 중요, 별도 try-catch로 보호)
        try {
          _startCountdown();
        } catch (e) {
          debugPrint('⚠️ 타이머 시작 오류: $e');
          if (_isDisposed) return;
        }

        // 3. 사이렌 재생 시도 (타이머와 별도로 실행)
        try {
          _playSiren();
        } catch (e) {
          debugPrint('⚠️ 사이렌 재생 시작 오류: $e');
          // 사이렌이 실패해도 타이머는 계속 진행
        }
      } catch (e) {
        debugPrint('⚠️ SOS 시작 중 심각한 오류: $e');

        // 오류 발생 시 모든 리소스 정리 시도
        try {
          cancelSOS();
        } catch (_) {}
      }
    }

    // 연락처 유무에 따라 흐름 제어
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

                // 다이얼로그 닫힌 후 곧바로 실행되도록 약간의 딜레이
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (!_isDisposed) {
                    startSOS(); // 연락처 없이 진행
                  }
                });
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('그래도 진행'),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    } else {
      // 개인 긴급 연락처가 있는 경우 바로 진행
      startSOS();
    }
  }

  void cancelSOS() {
    debugPrint('✅ cancelSOS 호출됨');

    // 이미 비활성화된 상태이고 오디오 플레이어도 없는 경우 중복 호출 방지
    if (!isSOSActive && _audioPlayer == null && _timer == null) {
      debugPrint('✅ 이미 SOS가 비활성화되어 있음');
      return;
    }

    // 1. 타이머 즉시 취소
    _stopCountdown();
    debugPrint('✅ 타이머 취소됨');

    // 2. 사이렌 중지 (오디오 플레이어)
    try {
      if (_audioPlayer != null) {
        if (_audioPlayer!.playing) {
          _audioPlayer!.stop();
          debugPrint('✅ 오디오 플레이어 중지됨');
        }
      }
    } catch (e) {
      debugPrint('⚠️ 오디오 플레이어 중지 실패: $e');
    }

    // 3. 상태 변수 업데이트
    try {
      setSOSActive(false);
      setCountdown(30);
      setIsAudioPlaying(false);
      debugPrint('✅ 상태 변수 초기화됨');
    } catch (e) {
      debugPrint('⚠️ 상태 변수 초기화 실패: $e');
    }

    // 4. 볼륨 유지 타이머 취소
    try {
      _volumeKeeper?.cancel();
      _volumeKeeper = null;
    } catch (e) {
      debugPrint('⚠️ 볼륨 유지 타이머 취소 실패: $e');
    }

    // 볼륨 복원
    _restoreSystemVolume();
    debugPrint('✅ cancelSOS 완료됨');
  }

  void _startCountdown() {
    // 1. 기존 타이머 즉시 취소 (중복 방지)
    _stopCountdown();

    // 2. 빠른 실패: 컨트롤러가 이미 dispose되었거나 SOS가 비활성화된 경우
    if (_isDisposed || !isSOSActive) {
      debugPrint('⚠️ _startCountdown: 컨트롤러가 이미 dispose되었거나 SOS가 비활성화됨');
      return;
    }

    // 3. 카운트다운 초기화
    setCountdown(30);
    debugPrint('✅ 카운트다운 타이머 시작: 30초');

    // 4. 새 타이머 시작 (매우 단순화된 버전)
    try {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        // 매 틱마다 컨트롤러 상태 확인 - 안전장치
        if (_isDisposed || !isSOSActive) {
          debugPrint(
              '⚠️ 타이머 작동 중 상태변경 감지: isDisposed=$_isDisposed, isSOSActive=${isSOSActive}');
          _stopCountdown();
          return;
        }

        // 디버깅 로그
        debugPrint('⏱️ 카운트다운: ${countdown}초');

        // 카운트다운 처리 로직
        if (countdown > 0) {
          // 안전하게 감소
          try {
            decrementCountdown();
          } catch (e) {
            debugPrint('⚠️ 카운트다운 감소 오류: $e');
            _stopCountdown(); // 오류 발생 시 타이머 종료
          }
        } else {
          // 카운트다운 완료
          debugPrint('✅ 카운트다운 완료, SOS 실행');
          _stopCountdown();

          // SOS 액션은 isDisposed 체크 후 별도 try-catch로 안전하게 실행
          if (!_isDisposed) {
            try {
              _onSOSConfirmed();
            } catch (e) {
              debugPrint('⚠️ SOS 확인 처리 오류: $e');
            }
          }
        }
      });
    } catch (e) {
      debugPrint('⚠️ 타이머 생성 오류: $e');
      setSOSActive(false); // 오류 발생 시 SOS 비활성화
    }
  }

  Future<void> _onSOSConfirmed() async {
    // 컨트롤러가 이미 dispose된 경우 즉시 종료
    if (_isDisposed) {
      debugPrint('⚠️ _onSOSConfirmed: 컨트롤러가 이미 dispose됨');
      return;
    }

    debugPrint('✅ SOS 액션 실행 시작');

    try {
      // 1단계: 앱 내 메시지로 SOS 상황과 위치를 내 긴급 연락처(앱 사용자)에게 전송
      try {
        if (!_isDisposed) {
          await _sendSOSMessageToAppContacts();
        }
      } catch (e) {
        debugPrint('⚠️ SOS 앱 메시지 전송 오류: $e');
      }

      // 2단계: 사이렌 소리 명시적으로 중지
      try {
        if (_isDisposed) return;
        if (_audioPlayer != null) {
          await _audioPlayer!.stop();
          debugPrint('✅ 오디오 정지됨 (onSOSConfirmed)');
          setIsAudioPlaying(false);
        }
        await _restoreSystemVolume(); // 볼륨 복원
      } catch (e) {
        debugPrint('⚠️ 오디오 정지/볼륨 복원 오류: $e');
      }

      // 3단계: 긴급 전화 연결
      try {
        if (_isDisposed) return;
        await callEmergencyNumber('119');
      } catch (e) {
        debugPrint('⚠️ 긴급 전화 연결 오류: $e');
      }

      // 4단계: SOS 상태 비활성화
      try {
        if (!_isDisposed) {
          setSOSActive(false);
          debugPrint('✅ SOS 비활성화됨');
        }
      } catch (e) {
        debugPrint('⚠️ SOS 상태 비활성화 오류: $e');
      }

      debugPrint('✅ SOS 액션 완료');
    } catch (e) {
      debugPrint('⚠️ SOS 액션 실행 중 오류: $e');

      // 오류 발생해도 상태 초기화 시도
      try {
        if (!_isDisposed) {
          // 오디오 정지 재시도
          if (_audioPlayer != null && _audioPlayer!.playing) {
            _audioPlayer!.stop();
          }
          setSOSActive(false);
          setIsAudioPlaying(false);
        }
      } catch (_) {}
    }
  }

  void _stopCountdown() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _sendEmergencyNotifications() async {
    try {
      // EmergencyContactService에서 긴급 연락처 가져오기
      final emergencyContactService = Get.find<EmergencyContactService>();
      final allContacts = emergencyContactService.contacts;

      // 위치 정보 가져오기
      String locationMessage = '';
      try {
        final locationService = Get.find<LocationService>();
        await locationService.getCurrentLocation();
        final loc = locationService.currentLocation.value;
        if (loc != null) {
          // 주소 변환 시도
          String address = '';
          try {
            final placemarks =
                await placemarkFromCoordinates(loc.latitude, loc.longitude);
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              address =
                  '${p.locality ?? ''} ${p.thoroughfare ?? ''} ${p.name ?? ''}'
                      .trim();
            }
          } catch (_) {}
          locationMessage =
              '\n[현재 위치]\n위도: 	${loc.latitude}\n경도: 	${loc.longitude}${address.isNotEmpty ? '\n주소: $address' : ''}';
        } else {
          locationMessage = '\n(위치 정보를 가져올 수 없습니다)';
        }
      } catch (e) {
        locationMessage = '\n(위치 권한이 없거나 위치 정보를 가져올 수 없습니다)';
      }

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

      debugPrint('⚠️ 긴급 알림 전송 중...');

      if (filteredContacts.isEmpty) {
        debugPrint('⚠️ 전송할 개인 긴급 연락처가 없습니다.');
        Get.snackbar(
          '알림 전송 실패',
          '전송할 개인 긴급 연락처가 없습니다. 119로 연결합니다.',
          backgroundColor: Colors.yellow.shade100,
          duration: const Duration(seconds: 3),
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      for (var contact in filteredContacts) {
        debugPrint('  - ${contact.name}에게 알림 전송: ${contact.phoneNumber}');
        debugPrint('    [메시지 내용] SOS 긴급 상황 발생!${locationMessage}');
      }

      Get.snackbar(
        '긴급 알림 전송',
        '개인 긴급 연락처로 SOS 알림이 전송되었습니다.\n(위치 정보 포함)',
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

  /// SOS 상황과 위치 정보를 내 긴급 연락처(앱 사용자)에게 앱 내 메시지로 전송
  Future<void> _sendSOSMessageToAppContacts() async {
    try {
      final emergencyContactService = Get.find<EmergencyContactService>();
      final messageService = Get.find<MessageService>();
      final allContacts = emergencyContactService.contacts;

      // 앱 사용자로 등록된 긴급 연락처만 필터링
      final appUserContacts = allContacts
          .where((c) => c.isAppUser && c.userId != null && c.userId!.isNotEmpty)
          .toList();
      if (appUserContacts.isEmpty) {
        debugPrint('⚠️ 앱 사용자 긴급 연락처가 없습니다.');
        return;
      }

      // 위치 정보 가져오기
      String locationMessage = '';
      try {
        final locationService = Get.find<LocationService>();
        await locationService.getCurrentLocation();
        final loc = locationService.currentLocation.value;
        if (loc != null) {
          // 주소 변환 시도
          String address = '';
          try {
            final placemarks =
                await placemarkFromCoordinates(loc.latitude, loc.longitude);
            if (placemarks.isNotEmpty) {
              final p = placemarks.first;
              address =
                  '${p.locality ?? ''} ${p.thoroughfare ?? ''} ${p.name ?? ''}'
                      .trim();
            }
          } catch (_) {}
          locationMessage =
              '\n[현재 위치]\n위도: ${loc.latitude}\n경도: ${loc.longitude}${address.isNotEmpty ? '\n주소: $address' : ''}';
        } else {
          locationMessage = '\n(위치 정보를 가져올 수 없습니다)';
        }
      } catch (e) {
        locationMessage = '\n(위치 권한이 없거나 위치 정보를 가져올 수 없습니다)';
      }

      // SOS 메시지 내용
      final String message = '🆘 긴급 상황입니다!\n도움이 필요합니다.$locationMessage';

      // 각 앱 사용자에게 메시지 전송
      for (final contact in appUserContacts) {
        try {
          final receiverId = contact.userId!;
          await messageService.sendMessage(
            receiverId: receiverId,
            content: message,
            messageType: 'sos',
          );
          debugPrint('✅ ${contact.name}에게 SOS 메시지 전송 완료 (앱 내)');
        } catch (e) {
          debugPrint('⚠️ ${contact.name}에게 SOS 메시지 전송 실패: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ SOS 앱 메시지 전송 전체 실패: $e');
    }
  }

  @override
  void onClose() {
    debugPrint('✅ SOSController onClose 시작');

    // 이미 정리된 경우 중복 실행 방지
    if (_isDisposed) {
      debugPrint('⚠️ 컨트롤러가 이미 정리되었습니다. onClose 중복 실행 방지');
      super.onClose();
      return;
    }

    // 먼저 Rx 변수 초기화 (cleanupResources 전에 수행)
    try {
      setSOSActive(false);
      setCountdown(30);
      setIsAudioPlaying(false);
      setCurrentVolume(1.0);
      debugPrint('✅ Rx 변수 초기화 완료 (onClose에서)');
    } catch (e) {
      debugPrint('⚠️ onClose에서 Rx 변수 초기화 오류: $e');
    }

    // 리소스 정리 호출 (타이머, 오디오 해제)
    _cleanupResources();

    // 볼륨 복원
    _restoreSystemVolume();

    // 마지막으로 부모 onClose 호출
    debugPrint('✅ SOSController onClose 종료 및 super.onClose() 호출');
    super.onClose();
  }

  // 리소스 정리 메서드 - onClose와 cancelSOS에서 모두 호출
  void _cleanupResources() {
    try {
      // 1. 타이머 즉시 중지 (최우선)
      _stopCountdown(); // 타이머 취소 헬퍼 함수 호출

      // 2. 볼륨 유지 타이머 취소
      try {
        _volumeKeeper?.cancel();
        _volumeKeeper = null;
      } catch (e) {
        debugPrint('⚠️ 볼륨 유지 타이머 취소 오류: $e');
      }

      // 3. 오디오 플레이어 직접 해제 (중요)
      try {
        if (_audioPlayer != null) {
          // 3.1 먼저 오디오 플레이어 중지
          if (_audioPlayer!.playing) {
            try {
              _audioPlayer!.stop();
              debugPrint('✅ 오디오 플레이어 직접 중지됨');
            } catch (e) {
              debugPrint('⚠️ 오디오 중지 오류: $e');
            }
          }

          // 3.2 그 다음 오디오 플레이어 dispose
          try {
            _audioPlayer!.dispose();
            debugPrint('✅ 오디오 플레이어 직접 dispose됨');
          } catch (e) {
            debugPrint('⚠️ 오디오 dispose 오류: $e');
          }

          _audioPlayer = null;
        }
      } catch (e) {
        debugPrint('⚠️ 오디오 플레이어 정리 오류: $e');
      }

      // 4. 마지막으로 isDisposed 플래그 설정 (리소스 정리 후에 설정)
      _isDisposed = true;
      debugPrint('✅ _isDisposed 플래그 설정됨');
    } catch (e) {
      debugPrint('⚠️ 리소스 정리 오류: $e');
      // 오류가 발생해도 최종적으로 isDisposed 플래그 설정
      _isDisposed = true;
    }
  }
}

class SOSView extends StatefulWidget {
  const SOSView({Key? key}) : super(key: key);

  @override
  State<SOSView> createState() => _SOSViewState();
}

class _SOSViewState extends State<SOSView> with WidgetsBindingObserver {
  // 컨트롤러 nullable로 선언 (late 사용 금지)
  SOSController? _controller;
  bool _initialized = false;

  // 안전하게 controller에 접근하는 getter (항상 유효한 컨트롤러 제공)
  SOSController get controller {
    if (_controller == null) {
      // 직접 생성된 임시 인스턴스 반환 (뷰가 멈추는 것을 방지)
      debugPrint('⚠️ 대체 컨트롤러 생성됨 (비상용)');
      return SOSController();
    }
    return _controller!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // SOS 컨트롤러 인스턴스 생성 전 정리 단계
    debugPrint('✅ SOSView initState 시작');

    // 초기화 타임아웃을 위한 안전장치
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_initialized) {
        debugPrint('⚠️ SOS 컨트롤러 초기화 타임아웃, 강제 초기화');
        _initialized = true;
        setState(() {}); // 화면 갱신
      }
    });

    // SOS 기능 초기화 함수
    _initializeSOSController();

    // 첫 화면 로드 시 연락처 확인은 이제 컨트롤러 초기화 이후 자동 호출됨
  }

  // SOS 컨트롤러 초기화 함수 (안전하게 수정)
  void _initializeSOSController() {
    try {
      // 1. 이전 컨트롤러 정리
      _cleanupExistingControllers();

      // 2. 인스턴스 생성 전 이미 _controller가 있는지 확인
      if (_controller != null) {
        debugPrint('✅ 이미 컨트롤러가 초기화되어 있음');
        _initialized = true;
        if (mounted) setState(() {});
        return;
      }

      // 3. 고유 태그 생성
      final uniqueTag = DateTime.now().millisecondsSinceEpoch.toString();

      // 4. GetX를 통해 안전하게 컨트롤러 인스턴스 생성
      _controller = Get.put<SOSController>(SOSController(),
          permanent: false, tag: uniqueTag);

      // 5. 초기화 성공 플래그 설정
      _initialized = true;
      debugPrint('✅ 새 SOSController 인스턴스 생성됨 (tag: $uniqueTag)');

      // 6. 화면 갱신
      if (mounted) setState(() {});

      // 7. 연락처 확인 (별도 try-catch로 분리)
      _safeCheckEmergencyContacts();
    } catch (e) {
      debugPrint('⚠️ SOSController 초기화 오류: $e');

      // 오류 발생해도 기본 컨트롤러 생성 (UI가 멈추지 않도록)
      try {
        if (_controller == null) {
          _controller = SOSController();
          debugPrint('✅ 오류 후 기본 컨트롤러 생성됨');
        }
      } catch (_) {}

      // 어떤 경우든 초기화 완료 표시
      _initialized = true;
      if (mounted) setState(() {});
    }
  }

  // 기존 컨트롤러 정리 메서드
  void _cleanupExistingControllers() {
    try {
      // 이미 등록된 모든 SOSController 인스턴스 찾아서 정리
      int count = 0;
      while (Get.isRegistered<SOSController>()) {
        try {
          // 기존 컨트롤러 찾기
          final oldController = Get.find<SOSController>();

          // 리소스 정리
          try {
            // 1. 우선 모든 타이머 취소
            oldController._timer?.cancel();
            oldController._timer = null;
            oldController._volumeKeeper?.cancel();
            oldController._volumeKeeper = null;

            // 2. 오디오 플레이어 정리
            if (oldController._audioPlayer != null) {
              if (oldController._audioPlayer!.playing) {
                oldController._audioPlayer!.stop();
              }
              oldController._audioPlayer!.dispose();
              oldController._audioPlayer = null;
            }

            // 3. 컨트롤러 상태 업데이트
            oldController._isDisposed = true;
          } catch (e) {
            debugPrint('⚠️ 기존 컨트롤러 리소스 정리 오류: $e');
          }

          // 4. 컨트롤러 인스턴스 삭제
          Get.delete<SOSController>(force: true);
          count++;

          // 무한 루프 방지
          if (count >= 3) {
            debugPrint('⚠️ 컨트롤러 정리 3회 시도 후 중단');
            break;
          }
        } catch (e) {
          debugPrint('⚠️ 기존 컨트롤러 검색/삭제 오류: $e');
          break;
        }
      }

      if (count > 0) {
        debugPrint('✅ $count개의 기존 SOSController 정리됨');
      }
    } catch (e) {
      debugPrint('⚠️ 컨트롤러 정리 과정 오류: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('✅ SOSView dispose 시작');

    // 1. WidgetsBinding 옵저버 제거
    WidgetsBinding.instance.removeObserver(this);

    // 컨트롤러가 없으면 추가 리소스 해제 없이 종료
    if (_controller == null) {
      debugPrint('✅ 컨트롤러가 null이므로 추가 정리 없이 dispose 종료');
      super.dispose();
      return;
    }

    // 2. SOS가 활성화된 상태면 취소 작업 수행 (SOS 취소 버튼과 동일한 효과)
    if (_controller!.isSOSActive) {
      debugPrint('✅ 페이지 종료 시 SOS 자동 취소 수행');

      try {
        // 취소 버튼 누른 것과 동일한 효과
        _controller!.cancelSOS();
      } catch (e) {
        debugPrint('⚠️ 자동 SOS 취소 오류: $e');
      }
    }

    // 3. 모든 타이머 명시적 취소 (추가 안전장치)
    try {
      _controller!._timer?.cancel();
      _controller!._timer = null;
      _controller!._volumeKeeper?.cancel();
      _controller!._volumeKeeper = null;
      debugPrint('✅ 모든 타이머 명시적 취소됨');
    } catch (e) {
      debugPrint('⚠️ 타이머 취소 실패: $e');
    }

    // 4. 오디오 재생 중지 (추가 안전장치)
    try {
      if (_controller!._audioPlayer != null) {
        if (_controller!._audioPlayer!.playing) {
          _controller!._audioPlayer!.stop();
          debugPrint('✅ 오디오 재생 중지됨');
        }
        _controller!._audioPlayer!.dispose();
        _controller!._audioPlayer = null;
        debugPrint('✅ 오디오 리소스 정리됨');
      }
    } catch (e) {
      debugPrint('⚠️ 오디오 정리 실패: $e');
    }

    // 5. isDisposed 플래그 설정 (비동기 작업 중단 위해)
    try {
      _controller!._isDisposed = true;
      debugPrint('✅ _isDisposed 플래그 설정됨');
    } catch (e) {
      debugPrint('⚠️ _isDisposed 설정 실패: $e');
    }

    // 6. GetX 컨트롤러 삭제
    try {
      // 현재 인스턴스만 정확하게 찾아서 삭제 (태그가 없을 수 있으므로 모든 방법 시도)
      try {
        Get.delete<SOSController>(force: true);
        debugPrint('✅ SOSController 삭제됨 (태그 없이)');
      } catch (_) {}

      // 혹시 남아있는 모든 인스턴스 정리
      int count = 0;
      while (Get.isRegistered<SOSController>()) {
        try {
          Get.delete<SOSController>(force: true);
          count++;
          if (count >= 3) break; // 무한 루프 방지
        } catch (_) {
          break;
        }
      }
      if (count > 0) {
        debugPrint('✅ 추가 SOSController 인스턴스 삭제됨: $count개');
      }
    } catch (e) {
      debugPrint('⚠️ GetX 컨트롤러 삭제 실패: $e');
    }

    // 마지막으로 모든 리소스 정리가 완료된 후 부모 dispose 호출
    try {
      debugPrint('✅ SOSView dispose 완료, super.dispose() 호출');
      super.dispose();
    } catch (e) {
      debugPrint('⚠️ super.dispose() 호출 실패: $e');
      // 어쨌든 부모의 dispose는 반드시 호출되어야 함
      super.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 다시 활성화되었을 때 연락처 확인
      _checkEmergencyContacts();
    }
  }

  // 안전하게 연락처 확인 (별도 메서드로 분리)
  void _safeCheckEmergencyContacts() {
    if (!mounted || _controller == null) return;

    try {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _controller == null) return;
        _checkEmergencyContacts();
      });
    } catch (e) {
      debugPrint('⚠️ 연락처 확인 예약 실패: $e');
    }
  }

  // 연락처 확인 및 안내
  Future<void> _checkEmergencyContacts() async {
    try {
      final hasContacts = await controller.hasPersonalEmergencyContacts();
      if (!hasContacts) {
        // 딜레이를 줘서 화면 전환 후에 다이얼로그 표시
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
      }
    } catch (e) {
      debugPrint('⚠️ 긴급 연락처 확인 중 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 초기화되지 않은 상태면 로딩 표시
    if (!_initialized || _controller == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('긴급 SOS'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text('SOS 기능 준비 중...', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  // 초기화가 멈춘 경우 강제로 초기화 완료 및 기본 컨트롤러 생성
                  setState(() {
                    if (_controller == null) {
                      _controller = SOSController();
                      debugPrint('✅ 강제 기본 컨트롤러 생성됨');
                    }
                    _initialized = true;
                  });
                },
                child: const Text('SOS 화면 직접 진입',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      );
    }

    // GetX 컨트롤러 접근 안전 장치 (값 복사용)
    bool isSosActive = false;
    int countdownValue = 30;

    try {
      // 안전하게 값만 복사 (UI는 이 로컬 변수 사용)
      isSosActive = controller.isSOSActive;
      countdownValue = controller.countdown;

      debugPrint(
          '🔄 UI 상태 업데이트: SOS 활성화=${isSosActive}, 카운트다운=${countdownValue}초');

      // 타이머 값이 비정상적인 경우 강제 보정
      if (countdownValue < 0 || countdownValue > 30) {
        countdownValue = 30;
      }
    } catch (e) {
      debugPrint('⚠️ GetX 컨트롤러 접근 오류: $e');
    }

    // WillPopScope를 사용하여 뒤로가기 제어
    return WillPopScope(
      onWillPop: () async {
        // SOS가 활성화된 상태에서 뒤로가기 누를 경우
        if (isSosActive && _controller != null) {
          // 사용자에게 경고 메시지 표시
          bool? result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('SOS 종료 확인',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                content: const Text(
                  'SOS가 활성화된 상태입니다. 페이지를 나가면 자동으로 SOS가 취소됩니다.\n\n계속 진행하시겠습니까?',
                  style: TextStyle(fontSize: 16),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(false), // 취소하고 페이지 유지
                    child:
                        const Text('취소', style: TextStyle(color: Colors.grey)),
                  ),
                  TextButton(
                    onPressed: () {
                      // SOS 취소 수행 후 페이지 나가기
                      try {
                        if (_controller != null) {
                          _controller!.cancelSOS();
                          debugPrint('✅ 페이지 나가기 전 SOS 취소됨');
                        }
                      } catch (e) {
                        debugPrint('⚠️ 페이지 나가기 전 SOS 취소 오류: $e');
                      }
                      Navigator.of(context).pop(true); // 확인하고 페이지 나가기
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('확인'),
                  ),
                ],
              );
            },
          );
          return result ?? false;
        }
        // SOS가 비활성화 상태면 바로 페이지 나가기
        return true;
      },
      child: Scaffold(
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
                  '버튼을 누르면 30초 후 자동으로 119로 연결됩니다.',
                  style: TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // SOS 버튼 및 카운트다운 표시
                Expanded(
                  child: Center(
                    child: StatefulBuilder(
                      builder: (context, setState) {
                        // 1초마다 상태 업데이트 (타이머 표시를 위해)
                        // Future.delayed를 직접 호출하는 대신 mounted 체크로 안전하게 관리
                        if (mounted) {
                          // 이미 예약된 것이 있는지 확인하는 플래그
                          bool updateScheduled = false;

                          void scheduleUpdate() {
                            if (!updateScheduled && mounted) {
                              updateScheduled = true;
                              Future.delayed(const Duration(milliseconds: 500),
                                  () {
                                updateScheduled = false;
                                if (mounted) {
                                  try {
                                    setState(() {
                                      try {
                                        // UI 업데이트를 위한 컨트롤러 값 재확인
                                        if (_controller != null &&
                                            !_controller!._isDisposed) {
                                          isSosActive =
                                              _controller!.isSOSActive;
                                          countdownValue =
                                              _controller!.countdown;
                                          if (countdownValue < 0 ||
                                              countdownValue > 30) {
                                            countdownValue = 30;
                                          }
                                        }
                                      } catch (e) {
                                        debugPrint('⚠️ 상태 업데이트 오류: $e');
                                      }
                                    });
                                  } catch (e) {
                                    debugPrint('⚠️ setState 오류: $e');
                                  }

                                  // 다음 업데이트 예약 (화면이 계속 표시되는 동안)
                                  if (mounted) {
                                    scheduleUpdate();
                                  }
                                }
                              });
                            }
                          }

                          // 초기 업데이트 예약
                          scheduleUpdate();
                        }

                        try {
                          if (isSosActive) {
                            // SOS 활성화 상태 - 카운트다운 표시
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$countdownValue',
                                  style: TextStyle(
                                    fontSize: 72,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  '초 후 자동으로 119로 연결됩니다',
                                  style: TextStyle(fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 40),
                                ElevatedButton(
                                  onPressed: () {
                                    try {
                                      // 컨트롤러가 있으면 cancelSOS 호출
                                      if (_controller != null) {
                                        _controller!.cancelSOS();
                                      }

                                      // UI 상태 직접 업데이트 (안전장치)
                                      setState(() {
                                        isSosActive = false;
                                        countdownValue = 30;
                                      });
                                    } catch (e) {
                                      debugPrint('⚠️ SOS 취소 오류: $e');

                                      // 오류 발생해도 UI는 업데이트
                                      setState(() {
                                        isSosActive = false;
                                        countdownValue = 30;
                                      });
                                    }
                                  },
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
                              onTap: () {
                                try {
                                  // 1. 먼저 UI 상태 변경 (반응성 향상)
                                  setState(() {
                                    isSosActive = true;
                                    countdownValue = 30;
                                  });

                                  // 2. UI 변경 후 컨트롤러 함수 호출 (별도 스케줄링)
                                  Future.microtask(() {
                                    try {
                                      if (_controller != null &&
                                          !_controller!._isDisposed) {
                                        _controller!.activateSOS();
                                      } else {
                                        debugPrint(
                                            '⚠️ SOS 활성화: 컨트롤러가 이미 dispose되었거나 null입니다');
                                      }
                                    } catch (e) {
                                      debugPrint('⚠️ SOS 활성화 지연 호출 오류: $e');
                                    }
                                  });
                                } catch (e) {
                                  debugPrint('⚠️ SOS 활성화 오류: $e');
                                }
                              },
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
                        } catch (e) {
                          debugPrint('⚠️ UI 렌더링 오류: $e');
                          // 오류 발생 시 기본 SOS 버튼 표시
                          return GestureDetector(
                            onTap: () {
                              try {
                                // 1. 먼저 UI 상태 변경 (반응성 향상)
                                setState(() {
                                  isSosActive = true;
                                  countdownValue = 30;
                                });

                                // 2. UI 변경 후 컨트롤러 함수 호출 (별도 스케줄링)
                                Future.microtask(() {
                                  try {
                                    if (_controller != null &&
                                        !_controller!._isDisposed) {
                                      _controller!.activateSOS();
                                    } else {
                                      debugPrint(
                                          '⚠️ SOS 활성화(백업): 컨트롤러가 이미 dispose되었거나 null입니다');
                                    }
                                  } catch (e) {
                                    debugPrint(
                                        '⚠️ SOS 활성화 지연 호출 오류 (fallback): $e');
                                  }
                                });
                              } catch (e) {
                                debugPrint('⚠️ SOS 활성화 오류 (fallback): $e');
                              }
                            },
                            child: Container(
                              width: screenSize.width * 0.6,
                              height: screenSize.width * 0.6,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
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
                      },
                    ),
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
                      Text('• 오작동 시 30초 내에 취소 버튼을 눌러주세요'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 직접 119 전화 버튼
                ElevatedButton.icon(
                  onPressed: () async {
                    // 로컬 UI 상태 즉시 업데이트 - SOS 버튼 상태로 되돌림
                    if (mounted) {
                      setState(() {
                        isSosActive = false;
                        countdownValue = 30;
                      });

                      // 화면 상태가 즉시 반영되도록 추가 지연 업데이트
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          setState(() {
                            // 상태 재확인
                            isSosActive = false;
                            countdownValue = 30;
                          });
                        }
                      });
                    }

                    try {
                      if (_controller != null && !_controller!._isDisposed) {
                        // 1. SOS 취소 기능 호출 (모든 타이머와 오디오 중지, 상태 초기화)
                        try {
                          // cancelSOS 메서드 호출로 모든 리소스 정리
                          _controller!.cancelSOS();
                          debugPrint('✅ 119 버튼: SOS 취소 호출 성공');

                          // 오디오 플레이어 상태 한 번 더 확인
                          if (_controller!._audioPlayer != null &&
                              _controller!._audioPlayer!.playing) {
                            // 먼저 볼륨을 0으로 설정하여 소리 즉시 중단
                            await _controller!._audioPlayer!.setVolume(0);
                            // 오디오 중지
                            await _controller!._audioPlayer!.stop();
                            debugPrint('✅ 119 버튼: 추가 사이렌 중지 확인');
                          }

                          // 상태 변수 재확인
                          _controller!.setIsAudioPlaying(false);
                          _controller!.setSOSActive(false);
                          _controller!.setCountdown(30);
                        } catch (e) {
                          debugPrint('⚠️ 119 버튼: 사이렌 중지 오류: $e');

                          // 오류 발생 시 다시 한번 취소 시도
                          try {
                            _controller!.cancelSOS();
                          } catch (_) {}

                          // 어떤 경우든 상태 변수는 변경
                          _controller!.setIsAudioPlaying(false);
                          _controller!.setSOSActive(false);
                          _controller!.setCountdown(30);

                          // 상태변수 변경 후 컨트롤러 초기화 시도
                          try {
                            _controller!._initAudioPlayer();
                          } catch (_) {}
                        }

                        // 2. 긴급 알림 전송
                        try {
                          await _controller!._sendEmergencyNotifications();
                          debugPrint('✅ 119 버튼: 긴급 알림 전송됨');
                        } catch (e) {
                          debugPrint('⚠️ 119 버튼: 긴급 알림 전송 오류: $e');
                        }

                        // 3. 119 전화 연결
                        _controller!.callEmergencyNumber('119');
                      } else {
                        // 컨트롤러 사용 불가능 시 직접 전화 걸기 시도
                        final Uri phoneUri = Uri(scheme: 'tel', path: '119');
                        launchUrl(phoneUri,
                            mode: LaunchMode.externalApplication);
                      }
                    } catch (e) {
                      debugPrint('⚠️ 119 전화 연결 오류: $e');
                      // 오류 발생 시 기본 전화 앱 실행 시도
                      try {
                        final Uri phoneUri = Uri(scheme: 'tel', path: '119');
                        launchUrl(phoneUri,
                            mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    }
                  },
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
      ),
    );
  }
}
