import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class LoginViewModel extends GetxController {
  // 서비스 의존성
  final AuthService _authService;

  // 컨트롤러
  late TextEditingController emailController;
  late TextEditingController passwordController;

  // UI 상태
  final RxBool isPasswordVisible = false.obs;
  final RxBool rememberMe = false.obs;

  // SharedPreferences 키
  static const String _rememberMeKey = 'remember_me';
  static const String _emailKey = 'saved_email';
  static const String _passwordKey = 'saved_password';

  // 생성자
  LoginViewModel(this._authService);

  @override
  void onInit() {
    super.onInit();
    // 컨트롤러 초기화
    emailController = TextEditingController();
    passwordController = TextEditingController();

    // 저장된 로그인 정보 불러오기
    _loadSavedLoginInfo();
  }

  // 저장된 로그인 정보 불러오기
  Future<void> _loadSavedLoginInfo() async {
    try {
      debugPrint('🔍 저장된 로그인 정보 불러오기 시작');
      final prefs = await SharedPreferences.getInstance();

      // 저장된 키 확인
      final keys = prefs.getKeys();
      debugPrint('📋 SharedPreferences 저장된 키: $keys');

      // 로그인 정보 저장 설정 불러오기
      rememberMe.value = prefs.getBool(_rememberMeKey) ?? false;
      debugPrint('🔑 로그인 정보 저장 설정: ${rememberMe.value}');

      // 저장된 설정이 있으면 이메일과 비밀번호도 불러오기
      if (rememberMe.value) {
        final savedEmail = prefs.getString(_emailKey);
        final savedPassword = prefs.getString(_passwordKey);

        if (savedEmail != null && savedEmail.isNotEmpty) {
          emailController.text = savedEmail;
          debugPrint('📧 저장된 이메일 정보를 불러왔습니다');
        } else {
          debugPrint('⚠️ 저장된 이메일 정보가 없습니다');
        }

        if (savedPassword != null && savedPassword.isNotEmpty) {
          passwordController.text = savedPassword;
          debugPrint('🔐 저장된 비밀번호 정보를 불러왔습니다');
        } else {
          debugPrint('⚠️ 저장된 비밀번호 정보가 없습니다');
        }

        debugPrint('✅ 저장된 로그인 정보를 불러왔습니다.');
      } else {
        debugPrint('ℹ️ 로그인 정보 저장 설정이 비활성화되어 있습니다');
      }
    } catch (e) {
      debugPrint('⚠️ 저장된 로그인 정보 불러오기 실패: $e');
      debugPrint('⚠️ 오류 스택: ${StackTrace.current}');

      // 오류 발생 시 기본값으로 설정
      rememberMe.value = false;
    }
  }

  // 로그인 정보 저장하기
  Future<void> _saveLoginInfo(String email, String password) async {
    try {
      debugPrint('💾 로그인 정보 저장 시작');
      final prefs = await SharedPreferences.getInstance();

      // 로그인 정보 저장 설정 저장
      final rememberMeResult =
          await prefs.setBool(_rememberMeKey, rememberMe.value);
      debugPrint(
          '🔑 로그인 정보 저장 설정 저장 ${rememberMeResult ? '성공' : '실패'}: ${rememberMe.value}');

      // 체크박스가 활성화된 경우에만 로그인 정보 저장
      if (rememberMe.value) {
        final emailResult = await prefs.setString(_emailKey, email);
        final passwordResult = await prefs.setString(_passwordKey, password);

        debugPrint('📧 이메일 저장 ${emailResult ? '성공' : '실패'}');
        debugPrint('🔐 비밀번호 저장 ${passwordResult ? '성공' : '실패'}');

        if (emailResult && passwordResult) {
          debugPrint('✅ 로그인 정보가 저장되었습니다.');

          // 저장 후 확인
          final savedEmail = prefs.getString(_emailKey);
          final savedRememberMe = prefs.getBool(_rememberMeKey);
          debugPrint(
              '📋 저장 확인: 이메일=${savedEmail != null}, 설정=${savedRememberMe ?? false}');
        } else {
          debugPrint('⚠️ 일부 로그인 정보 저장에 실패했습니다.');
        }
      } else {
        // 저장하지 않기로 했다면 기존 정보 삭제
        final removeEmailResult = await prefs.remove(_emailKey);
        final removePasswordResult = await prefs.remove(_passwordKey);

        debugPrint('🗑️ 저장된 이메일 삭제 ${removeEmailResult ? '성공' : '실패'}');
        debugPrint('🗑️ 저장된 비밀번호 삭제 ${removePasswordResult ? '성공' : '실패'}');

        if (removeEmailResult && removePasswordResult) {
          debugPrint('✅ 저장된 로그인 정보가 삭제되었습니다.');
        } else {
          debugPrint('⚠️ 일부 로그인 정보 삭제에 실패했습니다.');
        }
      }

      // 저장 후 키 목록 확인
      final keys = prefs.getKeys();
      debugPrint('📋 SharedPreferences 저장된 키: $keys');
    } catch (e) {
      debugPrint('⚠️ 로그인 정보 저장 실패: $e');
      debugPrint('⚠️ 오류 스택: ${StackTrace.current}');
    }
  }

  // Getters
  bool get isLoading => _authService.isLoading;
  String? get error => _authService.error;
  bool get isAuthenticated => _authService.isAuthenticated;

  // 비밀번호 표시/숨김 토글
  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  // 로그인 정보 저장 체크박스 토글
  void toggleRememberMe() {
    rememberMe.value = !rememberMe.value;
    debugPrint('✅ 로그인 정보 저장: ${rememberMe.value}');
  }

  // 로그인 처리
  Future<bool> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    // 입력 유효성 검사
    if (email.isEmpty || password.isEmpty) {
      _authService.setError('이메일과 비밀번호를 모두 입력해주세요');
      return false;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _authService.setError('유효한 이메일 주소를 입력해주세요');
      return false;
    }

    // 로그인 요청 - 자동 로그인 옵션 전달
    debugPrint('🔑 로그인 시도: 자동 로그인=${rememberMe.value}');
    final success =
        await _authService.login(email, password, rememberMe: rememberMe.value);

    // 로그인 성공 시 SharedPreferences에도 상태 저장 (UI 상태 유지용)
    if (success) {
      await _saveLoginInfo(email, password);
    }

    return success;
  }

  // 구글 로그인 처리
  Future<bool> loginWithGoogle() async {
    return await _authService.signInWithGoogle();
  }

  // 애플 로그인 처리
  Future<bool> loginWithApple() async {
    // 향후 애플 로그인 구현 시 추가
    _authService.setError('애플 로그인은 아직 지원되지 않습니다');
    return false;
  }

  // 카카오 로그인 처리
  Future<bool> loginWithKakao() async {
    // 향후 카카오 로그인 구현 시 추가
    _authService.setError('카카오 로그인은 아직 지원되지 않습니다');
    return false;
  }

  // 리소스 해제
  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
