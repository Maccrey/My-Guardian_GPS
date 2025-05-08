import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../view_models/login_view_model.dart';
import '../services/auth_service.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    // GetX 컨트롤러 초기화
    final controller = Get.put(LoginViewModel(Get.find<AuthService>()));

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
                          ElevatedButton(
                            onPressed: () {
                              // TODO: 추후 실제 로그인 기능 구현 시 아래 코드로 대체
                              // Obx(() => ElevatedButton(
                              //   onPressed: controller.isLoading
                              //     ? null
                              //     : () async {
                              //         if (await controller.login()) {
                              //           Get.snackbar(
                              //             '성공',
                              //             '로그인 성공!',
                              //             snackPosition: SnackPosition.BOTTOM,
                              //           );
                              //           Get.offAllNamed('/home');
                              //         } else if (controller.error != null) {
                              //           Get.snackbar(
                              //             '오류',
                              //             controller.error!,
                              //             snackPosition: SnackPosition.BOTTOM,
                              //           );
                              //         }
                              //       },
                              // )),

                              // 임시: 바로 홈 화면으로 이동
                              Get.offAllNamed('/home');
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
                            child: const Text(
                              '로그인',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildSocialButton(
                                context,
                                icon: Icons.g_mobiledata_rounded,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 24),
                              _buildSocialButton(
                                context,
                                icon: Icons.apple,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 24),
                              _buildSocialButton(
                                context,
                                icon: Icons.facebook,
                                color: Colors.blue.shade800,
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
      {required IconData icon, required Color color}) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 54,
        height: 54,
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
        child: Icon(
          icon,
          color: color,
          size: 28,
        ),
      ),
    );
  }
}
