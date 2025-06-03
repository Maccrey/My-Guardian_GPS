import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/biometric_service.dart';

class AppLockScreen extends StatelessWidget {
  const AppLockScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final BiometricService biometricService = Get.find<BiometricService>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade800, Colors.blue.shade500],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 앱 로고 또는 아이콘
                const Icon(
                  Icons.lock,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 30),

                // 앱 이름 또는 타이틀
                const Text(
                  '앱 잠금',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                // 안내 메시지
                const Text(
                  '계속하려면 생체 인증이 필요합니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 50),

                // 생체 인증 버튼
                ElevatedButton.icon(
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('생체 인증으로 잠금 해제'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.blue.shade800,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () async {
                    final success = await biometricService.authenticate();
                    if (success) {
                      Get.offAllNamed('/home');
                    }
                  },
                ),
                const SizedBox(height: 20),

                // 취소 버튼
                TextButton(
                  onPressed: () {
                    Get.offAllNamed('/');
                  },
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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
