import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  // 생성자
  LoginViewModel(this._authService);

  @override
  void onInit() {
    super.onInit();
    // 컨트롤러 초기화
    emailController = TextEditingController();
    passwordController = TextEditingController();
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

    // 로그인 요청
    return await _authService.login(email, password);
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
