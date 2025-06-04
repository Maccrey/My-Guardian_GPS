import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'location_service.dart';
import 'location_sharing_service.dart';
import 'image_cache_service.dart';
import 'biometric_service.dart';

class SettingsService extends GetxController {
  // 설정 상태 변수
  final RxBool isDarkMode = false.obs;
  final RxBool isLocationEnabled = true.obs;
  final RxBool isNotificationEnabled = true.obs;
  final RxBool isBiometricEnabled = false.obs;
  final RxBool isDataSavingEnabled = false.obs;

  // LocationService 인스턴스 - nullable로 변경
  LocationService? _locationService;

  // 위치 공유 서비스 인스턴스 - nullable로 변경
  LocationSharingService? _locationSharingService;

  // 이미지 캐시 서비스 인스턴스 - nullable로 변경
  ImageCacheService? _imageCacheService;

  // 생체인증 서비스 인스턴스 추가
  BiometricService? _biometricService;

  // 설정 키 상수
  static const String _darkModeKey = 'isDarkMode';
  static const String _locationEnabledKey = 'isLocationEnabled';
  static const String _notificationEnabledKey = 'isNotificationEnabled';
  static const String _biometricEnabledKey = 'isBiometricEnabled';
  static const String _dataSavingEnabledKey = 'isDataSavingEnabled';

  // Singleton 패턴 적용
  static SettingsService? _instance;

  static Future<SettingsService> getInstance() async {
    if (_instance == null) {
      _instance = SettingsService();
      await _instance!._init();
    }
    return _instance!;
  }

  // 초기화 함수
  Future<void> _init() async {
    try {
      // LocationService 인스턴스 가져오기
      if (Get.isRegistered<LocationService>()) {
        _locationService = Get.find<LocationService>();
      }

      // LocationSharingService 인스턴스 가져오기
      if (Get.isRegistered<LocationSharingService>()) {
        _locationSharingService = Get.find<LocationSharingService>();
      }

      // ImageCacheService 인스턴스 가져오기
      if (Get.isRegistered<ImageCacheService>()) {
        _imageCacheService = Get.find<ImageCacheService>();
      }

      // BiometricService 인스턴스 가져오기
      if (Get.isRegistered<BiometricService>()) {
        try {
          _biometricService = Get.find<BiometricService>();
          debugPrint('✅ SettingsService: BiometricService 찾음');
        } catch (e) {
          debugPrint('❌ SettingsService: BiometricService 찾기 실패 - $e');
          _biometricService = null;
        }
      } else {
        debugPrint('⚠️ SettingsService: BiometricService가 등록되지 않았습니다.');
        try {
          // 서비스가 등록되지 않은 경우 직접 등록 시도
          _biometricService = BiometricService();
          Get.put(_biometricService!, permanent: true);
          debugPrint('✅ SettingsService: BiometricService 등록 시도 완료');
        } catch (e) {
          debugPrint('❌ SettingsService: BiometricService 등록 실패 - $e');
          _biometricService = null;
        }
      }
    } catch (e) {
      debugPrint('⚠️ 서비스 인스턴스를 찾을 수 없습니다: $e');
      _locationService = null;
      _locationSharingService = null;
      _imageCacheService = null;
      _biometricService = null;
    }

    // 설정 불러오기
    await loadSettings();
  }

  // 설정 불러오기
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      isDarkMode.value = prefs.getBool(_darkModeKey) ?? false;
      isLocationEnabled.value = prefs.getBool(_locationEnabledKey) ?? true;
      isNotificationEnabled.value =
          prefs.getBool(_notificationEnabledKey) ?? true;
      isBiometricEnabled.value = prefs.getBool(_biometricEnabledKey) ?? false;
      isDataSavingEnabled.value = prefs.getBool(_dataSavingEnabledKey) ?? false;

      // 테마 설정 적용
      _applyTheme();

      // 위치 서비스 설정 적용
      _applyLocationServiceSettings();

      // 생체인증 설정 적용
      _applyBiometricSettings();

      print('✅ 설정 불러오기 완료');
    } catch (e) {
      print('⚠️ 설정 불러오기 오류: $e');
    }
  }

  // 설정 저장하기
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_darkModeKey, isDarkMode.value);
      await prefs.setBool(_locationEnabledKey, isLocationEnabled.value);
      await prefs.setBool(_notificationEnabledKey, isNotificationEnabled.value);
      await prefs.setBool(_biometricEnabledKey, isBiometricEnabled.value);
      await prefs.setBool(_dataSavingEnabledKey, isDataSavingEnabled.value);

      // 위치 서비스 설정 적용
      _applyLocationServiceSettings();

      // 데이터 절약 모드 설정 적용
      _applyDataSavingMode();

      print('✅ 설정 저장 완료');
    } catch (e) {
      print('⚠️ 설정 저장 오류: $e');
    }
  }

  // 테마 토글 기능
  Future<void> toggleTheme() async {
    isDarkMode.value = !isDarkMode.value;
    await saveSettings();
    _applyTheme();
  }

  // 현재 테마 적용 함수
  void _applyTheme() {
    if (isDarkMode.value) {
      Get.changeThemeMode(ThemeMode.dark);
    } else {
      Get.changeThemeMode(ThemeMode.light);
    }
  }

  // 위치 서비스 설정 적용
  void _applyLocationServiceSettings() {
    try {
      // LocationService가 초기화되어 있는지 확인
      if (_locationService != null) {
        _locationService!.setLocationServiceEnabled(isLocationEnabled.value);
        debugPrint(
            '✅ 위치 서비스 설정 적용됨: ${isLocationEnabled.value ? "활성화" : "비활성화"}');
      }
    } catch (e) {
      debugPrint('⚠️ 위치 서비스 설정 적용 오류: $e');
    }
  }

  // 추천 설정 적용하기
  Future<void> applyRecommendedSettings(String settingType) async {
    switch (settingType) {
      case 'privacy':
        isLocationEnabled.value = false;
        isNotificationEnabled.value = false;
        isBiometricEnabled.value = true;
        isDataSavingEnabled.value = false;
        break;
      case 'performance':
        isLocationEnabled.value = true;
        isNotificationEnabled.value = true;
        isBiometricEnabled.value = false;
        isDataSavingEnabled.value = true;
        break;
      case 'balanced':
        isLocationEnabled.value = true;
        isNotificationEnabled.value = true;
        isBiometricEnabled.value = true;
        isDataSavingEnabled.value = false;
        break;
      default:
        print('⚠️ 알 수 없는 설정 타입: $settingType');
        return;
    }

    await saveSettings();
    // 테마 설정 적용
    _applyTheme();
    print('✅ $settingType 추천 설정 적용 완료');
  }

  // 모든 설정 초기화
  Future<void> resetSettings() async {
    isDarkMode.value = false;
    isLocationEnabled.value = true;
    isNotificationEnabled.value = true;
    isBiometricEnabled.value = false;
    isDataSavingEnabled.value = false;

    await saveSettings();
    // 테마 설정 적용
    _applyTheme();
    print('✅ 설정 초기화 완료');
  }

  // 데이터 절약 모드 토글 메서드 추가
  Future<void> toggleDataSavingMode() async {
    isDataSavingEnabled.value = !isDataSavingEnabled.value;
    await saveSettings();
    _applyDataSavingMode();
  }

  // 데이터 절약 모드 설정 적용 메서드 추가
  void _applyDataSavingMode() {
    try {
      // LocationService 데이터 절약 모드 설정
      if (_locationService != null) {
        _locationService!.setDataSavingMode(isDataSavingEnabled.value);
        debugPrint(
            '✅ LocationService 데이터 절약 모드 설정 적용됨: ${isDataSavingEnabled.value ? "활성화" : "비활성화"}');
      }

      // LocationSharingService 데이터 절약 모드 설정
      if (_locationSharingService != null) {
        _locationSharingService!.setDataSavingMode(isDataSavingEnabled.value);
        debugPrint(
            '✅ LocationSharingService 데이터 절약 모드 설정 적용됨: ${isDataSavingEnabled.value ? "활성화" : "비활성화"}');
      }

      // ImageCacheService 데이터 절약 모드 설정
      if (_imageCacheService != null) {
        _imageCacheService!.setDataSavingMode(isDataSavingEnabled.value);
        debugPrint(
            '✅ ImageCacheService 데이터 절약 모드 설정 적용됨: ${isDataSavingEnabled.value ? "활성화" : "비활성화"}');
      }
    } catch (e) {
      debugPrint('⚠️ 데이터 절약 모드 설정 적용 오류: $e');
    }
  }

  // 생체인증 토글 메서드
  Future<void> toggleBiometricAuth() async {
    if (_biometricService == null) {
      print('⚠️ 생체인증 서비스를 찾을 수 없습니다.');
      Get.snackbar('오류', '생체인증 서비스를 사용할 수 없습니다');
      return;
    }

    // 생체인증 상태 새로고침 - 최신 상태 확인
    await _biometricService!.refreshBiometricStatus();

    // 생체인증 가능 여부 확인
    if (!_biometricService!.isBiometricAvailable.value) {
      print(
          '⚠️ 이 기기에서는 생체인증을 사용할 수 없습니다: ${_biometricService!.biometricError.value}');

      // 구체적인 오류 메시지가 있으면 해당 메시지 표시
      final errorMessage = _biometricService!.biometricError.value.isNotEmpty
          ? _biometricService!.biometricError.value
          : '이 기기에서는 생체인증을 사용할 수 없습니다';

      Get.snackbar('오류', errorMessage);
      isBiometricEnabled.value = false;
      await saveSettings();
      return;
    }

    // 활성화하는 경우 먼저 인증 요청
    if (!isBiometricEnabled.value) {
      print('🔍 생체인증 활성화 위한 인증 요청');
      final success = await _biometricService!.authenticate();
      if (!success) {
        print('⚠️ 생체인증 실패');
        return; // 이미 authenticate 메서드 내에서 스낵바 표시됨
      }
    }

    // 설정 변경
    isBiometricEnabled.value = !isBiometricEnabled.value;
    print('✅ 생체인증 설정 변경: ${isBiometricEnabled.value}');

    // 앱 잠금 설정 업데이트
    await _biometricService!.setAppLock(isBiometricEnabled.value);

    // 설정 저장
    await saveSettings();

    // 알림
    Get.snackbar(
      '생체인증 ${isBiometricEnabled.value ? '활성화' : '비활성화'}됨',
      isBiometricEnabled.value ? '앱 잠금에 생체인증이 사용됩니다' : '앱 잠금이 비활성화되었습니다',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  // 생체인증 설정 적용
  void _applyBiometricSettings() {
    if (_biometricService != null) {
      // 생체인증 상태 업데이트
      _biometricService!.refreshBiometricStatus();

      // 생체인증이 사용 불가능한데 활성화 상태라면 비활성화
      if (!_biometricService!.isBiometricAvailable.value &&
          isBiometricEnabled.value) {
        print('⚠️ 생체인증이 비활성화됨: 생체인증을 사용할 수 없음');
        isBiometricEnabled.value = false;
      }

      // 앱 잠금 설정 업데이트
      _biometricService!.setAppLock(isBiometricEnabled.value);
      print('✅ 생체인증 설정 적용: ${isBiometricEnabled.value ? "활성화" : "비활성화"}');
    }
  }

  // 생체인증 활성화 설정 변경
  Future<void> setBiometricEnabled(bool enabled) async {
    isBiometricEnabled.value = enabled;
    await saveSettings();

    // 생체 인증 서비스가 null인 경우 먼저 초기화 시도
    if (_biometricService == null) {
      debugPrint('⚠️ 생체인증 서비스가 null입니다. 초기화를 시도합니다.');
      try {
        if (Get.isRegistered<BiometricService>()) {
          _biometricService = Get.find<BiometricService>();
          debugPrint('✅ 생체인증 서비스를 성공적으로 찾았습니다.');
        } else {
          _biometricService = BiometricService();
          Get.put(_biometricService!, permanent: true);
          debugPrint('✅ 생체인증 서비스를 새로 등록했습니다.');
        }
      } catch (e) {
        debugPrint('❌ 생체인증 서비스 초기화 실패: $e');
        return;
      }
    }

    // 생체 인증 상태 새로고침
    try {
      await _biometricService!.refreshBiometricStatus();
    } catch (e) {
      debugPrint('❌ 생체인증 상태 새로고침 실패: $e');
    }

    // 생체 인증을 활성화하려는데 기기가 지원하지 않는 경우
    if (!_biometricService!.isBiometricAvailable.value && enabled) {
      debugPrint(
          '⚠️ 이 기기에서는 생체인증을 사용할 수 없습니다: ${_biometricService!.biometricError.value}');

      // 사용자에게 알림
      final errorMessage = _biometricService!.biometricError.value.isNotEmpty
          ? _biometricService!.biometricError.value
          : '이 기기에서는 생체인증을 사용할 수 없습니다.';

      Get.snackbar(
        '생체인증 사용 불가',
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      // 설정 값 롤백
      isBiometricEnabled.value = false;
      await saveSettings();
      return;
    }

    // 생체 인증을 활성화하는 경우 인증 확인
    if (enabled) {
      try {
        final success = await _biometricService!.authenticate();
        if (!success) {
          // 인증 실패 시 설정 값 롤백
          isBiometricEnabled.value = false;
          await saveSettings();
          return;
        }
      } catch (e) {
        debugPrint('❌ 생체인증 실패: $e');
        // 오류 발생 시 설정 값 롤백
        isBiometricEnabled.value = false;
        await saveSettings();
        return;
      }
    }

    // 앱 잠금 설정
    try {
      await _biometricService!.setAppLock(isBiometricEnabled.value);
    } catch (e) {
      debugPrint('❌ 앱 잠금 설정 실패: $e');
    }
  }
}
