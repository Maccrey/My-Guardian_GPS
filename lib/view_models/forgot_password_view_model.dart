import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';

class ForgotPasswordViewModel extends GetxController {
  // 서비스 의존성
  final AuthService _authService;

  // 컨트롤러
  late TextEditingController emailController;

  // 상태
  final RxBool _resetLinkSent = false.obs;

  // 생성자
  ForgotPasswordViewModel(this._authService);

  @override
  void onInit() {
    super.onInit();
    // 컨트롤러 초기화
    emailController = TextEditingController();
  }

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

    // 비밀번호 재설정 요청 - 수정된 부분: 실제 AuthService 메서드 호출
    try {
      final result = await _authService.sendPasswordResetEmail(email);

      if (result) {
        _resetLinkSent.value = true;
      }

      return result;
    } catch (e) {
      _authService.setError('비밀번호 재설정 링크 전송 중 오류가 발생했습니다: ${e.toString()}');
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
