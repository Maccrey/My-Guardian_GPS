import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'location_service.dart';
import 'location_sharing_service.dart';
import 'image_cache_service.dart';

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
    } catch (e) {
      debugPrint('⚠️ 서비스 인스턴스를 찾을 수 없습니다: $e');
      _locationService = null;
      _locationSharingService = null;
      _imageCacheService = null;
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
}
