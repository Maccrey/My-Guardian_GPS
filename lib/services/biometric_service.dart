import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricService extends GetxService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final RxBool isBiometricAvailable = false.obs;
  final RxBool isAppLocked = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkBiometricAvailability();
    _checkAppLockStatus();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      isBiometricAvailable.value =
          await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
      print('✅ 생체인증 가용성 확인: ${isBiometricAvailable.value}');
    } catch (e) {
      print('⚠️ 생체인증 가용성 확인 오류: $e');
      isBiometricAvailable.value = false;
    }
  }

  Future<void> _checkAppLockStatus() async {
    try {
      final status = await _storage.read(key: 'app_lock_status');
      isAppLocked.value = status == 'true';
      print('✅ 앱 잠금 상태 확인: ${isAppLocked.value}');
    } catch (e) {
      print('⚠️ 앱 잠금 상태 확인 오류: $e');
      isAppLocked.value = false;
    }
  }

  Future<bool> authenticate() async {
    if (!isBiometricAvailable.value) {
      print('⚠️ 생체인증 사용 불가능');
      return false;
    }

    try {
      print('🔍 생체인증 요청 시작');
      final bool result = await _auth.authenticate(
        localizedReason: '계속하려면 생체 인증이 필요합니다',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      print('✅ 생체인증 결과: $result');
      return result;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.permanentlyLockedOut) {
        print('⚠️ 생체인증 오류: ${e.code} - ${e.message}');
        Get.snackbar('오류', '기기에 생체 인증이 설정되어 있지 않습니다');
      } else {
        print('❌ 생체인증 오류: ${e.code} - ${e.message}');
        Get.snackbar('오류', '생체 인증 오류: ${e.message}');
      }
      return false;
    } catch (e) {
      print('❌ 생체인증 중 예상치 못한 오류: $e');
      Get.snackbar('오류', '생체 인증 중 오류가 발생했습니다');
      return false;
    }
  }

  Future<void> setAppLock(bool enabled) async {
    try {
      await _storage.write(key: 'app_lock_status', value: enabled.toString());
      isAppLocked.value = enabled;
      print('✅ 앱 잠금 설정 완료: $enabled');
    } catch (e) {
      print('❌ 앱 잠금 설정 오류: $e');
    }
  }
}
