import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';

class ForgotPasswordViewModel extends GetxController {
  // 서비스 의존성
  final AuthService _authService;

  // 컨트롤러
  final TextEditingController emailController = TextEditingController();

  // 상태
  final RxBool _resetLinkSent = false.obs;

  // 생성자
  ForgotPasswordViewModel(this._authService);

  // Getters
  bool get isLoading => _authService.isLoading;
  String? get error => _authService.error;
  bool get resetLinkSent => _resetLinkSent.value;

  // 비밀번호 재설정 링크 전송
  Future<bool> sendPasswordResetLink() async {
    final email = emailController.text.trim();

    // 이메일 유효성 검사
    if (email.isEmpty) {
      _authService.setError('이메일을 입력해주세요');
      return false;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _authService.setError('유효한 이메일 주소를 입력해주세요');
      return false;
    }

    // 비밀번호 재설정 요청
    _authService.setLoading(true);
    _authService.setError(null);

    try {
      // API 호출을 시뮬레이션
      await Future.delayed(const Duration(seconds: 2));

      // 실제 서비스에서는 서버에 비밀번호 재설정 요청을 보냄
      print('비밀번호 재설정 요청: $email');

      _resetLinkSent.value = true;
      _authService.setLoading(false);
      return true;
    } catch (e) {
      _authService.setError('비밀번호 재설정 링크 전송 중 오류가 발생했습니다: ${e.toString()}');
      _authService.setLoading(false);
      return false;
    }
  }

  // 리소스 해제
  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}
