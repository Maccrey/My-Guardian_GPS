import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../view_models/login_view_model.dart';
import '../services/auth_service.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    // GetX 컨트롤러 초기화 - put 대신 lazyPut을 사용하고 find로 가져오기
    Get.lazyPut(() => LoginViewModel(Get.find<AuthService>()), fenix: true);
    final controller = Get.find<LoginViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 로고와 환영 텍스트
                    const SizedBox(height: 20),
                    Center(
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 60,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      '로그인',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '계정에 로그인하고 서비스를 이용하세요.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 35),

                    // 로그인 폼
                    Form(
                      child: Column(
                        children: [
                          // 이메일 필드
                          TextFormField(
                            controller: controller.emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: '이메일',
                              hintText: 'your.email@example.com',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 비밀번호 필드
                          Obx(() => TextFormField(
                                controller: controller.passwordController,
                                obscureText:
                                    !controller.isPasswordVisible.value,
                                decoration: InputDecoration(
                                  labelText: '비밀번호',
                                  hintText: '비밀번호를 입력하세요',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      controller.isPasswordVisible.value
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () =>
                                        controller.togglePasswordVisibility(),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              )),

                          // 추가 옵션 (기억하기, 비밀번호 찾기)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Obx(() => Row(
                                    children: [
                                      Checkbox(
                                        value: controller.rememberMe.value,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        onChanged: (value) =>
                                            controller.toggleRememberMe(),
                                      ),
                                      const Text('로그인 정보 저장'),
                                    ],
                                  )),
                              TextButton(
                                onPressed: () {
                                  Get.toNamed('/forgot-password');
                                },
                                child: const Text('비밀번호 찾기'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // 로그인 버튼
                          Obx(() => ElevatedButton(
                                onPressed: controller.isLoading
                                    ? null
                                    : () async {
                                        if (await controller.login()) {
                                          Get.snackbar(
                                            '성공',
                                            '로그인 성공!',
                                            snackPosition: SnackPosition.BOTTOM,
                                          );
                                          Get.offAllNamed('/home');
                                        } else if (controller.error != null) {
                                          Get.snackbar(
                                            '오류',
                                            controller.error!,
                                            snackPosition: SnackPosition.BOTTOM,
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size.fromHeight(56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: controller.isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text(
                                        '로그인',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                              )),
                          const SizedBox(height: 16),

                          // 소셜 로그인 옵션
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '또는',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 소셜 로그인 버튼들
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildGoogleButton(context, controller),
                              _buildSocialButton(
                                context,
                                icon: Icons.apple,
                                color: Colors.black,
                                text: '애플',
                                onTap: () async {
                                  if (await controller.loginWithApple()) {
                                    Get.snackbar(
                                      '성공',
                                      '애플 로그인 성공!',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                    Get.offAllNamed('/home');
                                  } else if (controller.error != null) {
                                    Get.snackbar(
                                      '오류',
                                      controller.error!,
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  }
                                },
                              ),
                              _buildSocialButton(
                                context,
                                icon: Icons.chat_outlined,
                                color: const Color(0xFFFEE500),
                                text: '카카오',
                                onTap: () async {
                                  if (await controller.loginWithKakao()) {
                                    Get.snackbar(
                                      '성공',
                                      '카카오 로그인 성공!',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                    Get.offAllNamed('/home');
                                  } else if (controller.error != null) {
                                    Get.snackbar(
                                      '오류',
                                      controller.error!,
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),

                          // 회원가입 링크
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '아직 계정이 없으신가요?',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              TextButton(
                                onPressed: () {
                                  Get.toNamed('/register');
                                },
                                child: const Text(
                                  '회원가입',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Obx(() {
              if (controller.isLoading) {
                return Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              } else {
                return const SizedBox.shrink();
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(BuildContext context,
      {required IconData icon,
      required Color color,
      String? text,
      VoidCallback? onTap}) {
    final bool isKakao = color == const Color(0xFFFEE500);
    final bool isGoogle = color == const Color(0xFF4285F4);
    final bool isApple = color == Colors.black;

    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        height: 48,
        decoration: BoxDecoration(
          color: isKakao
              ? color
              : isApple
                  ? Colors.black
                  : isGoogle
                      ? Colors.white
                      : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isKakao
                  ? Colors.brown.shade800
                  : isApple
                      ? Colors.white
                      : color,
              size: 22,
            ),
            if (text != null) ...[
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: isKakao
                      ? Colors.brown.shade800
                      : isApple
                          ? Colors.white
                          : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleButton(BuildContext context, LoginViewModel controller) {
    return InkWell(
      onTap: () async {
        if (await controller.loginWithGoogle()) {
          Get.snackbar(
            '성공',
            '구글 로그인 성공!',
            snackPosition: SnackPosition.BOTTOM,
          );
          Get.offAllNamed('/home');
        } else if (controller.error != null) {
          Get.snackbar(
            '오류',
            controller.error!,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 흰색 원형 배경
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 2,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    // 구글의 "G" 문자
                    Text(
                      'G',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        foreground: Paint()
                          ..shader = LinearGradient(
                            colors: const [
                              Color(0xFF4285F4), // Google Blue
                              Color(0xFFDB4437), // Google Red
                              Color(0xFFF4B400), // Google Yellow
                              Color(0xFF0F9D58), // Google Green
                            ],
                            // 그라데이션 방향 조정 - 실제 구글 로고 색상 흐름과 비슷하게
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: const [0.0, 0.33, 0.67, 1.0],
                          ).createShader(const Rect.fromLTWH(0, 0, 24, 24)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '구글',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
