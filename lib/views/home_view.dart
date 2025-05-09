import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';
import 'emergency_contacts_view.dart';
import 'emergency_guide_view.dart';
import 'settings/settings_view.dart';

class HomeView extends StatelessWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();

    return Scaffold(
      appBar: AppBar(
        // title: const Text('GPS Search'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // 나중에 프로필 화면으로 이동하는 기능 추가
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // 로그아웃 확인 다이얼로그
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('정말 로그아웃 하시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('로그아웃'),
                    ),
                  ],
                ),
              );

              if (result == true) {
                await authService.logout();
                Get.offAllNamed('/');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 사용자 환영 메시지
              const Text(
                '안녕하세요!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'GPS Search와 함께 안전한 위치 공유를 시작하세요.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),

              // 주요 기능 카드
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildFeatureCard(
                      '위치 공유',
                      Icons.location_on,
                      Colors.blue.shade100,
                      () {
                        // 위치 공유 화면으로 이동
                      },
                    ),
                    _buildFeatureCard(
                      '귀가 알림',
                      Icons.home,
                      Colors.green.shade100,
                      () {
                        // 귀가 알림 화면으로 이동
                      },
                    ),
                    _buildFeatureCard(
                      '메시지',
                      Icons.message,
                      Colors.orange.shade100,
                      () {
                        // 메시지 화면으로 이동
                      },
                    ),
                    _buildFeatureCard(
                      'SOS',
                      Icons.emergency,
                      Colors.red.shade100,
                      () {
                        // SOS 화면으로 이동
                      },
                    ),
                    // ********************************************
                    // ****** 보호된 코드: 절대 수정하지 마세요 ******
                    // ****** PROTECTED CODE: DO NOT MODIFY ******
                    _buildFeatureCard(
                      '응급사항',
                      Icons.medical_services,
                      Colors.purple.shade100,
                      () {
                        // 응급 상황 가이드 화면으로 이동
                        Get.to(() => const EmergencyGuideView());
                      },
                    ),
                    // ********************************************
                    _buildFeatureCard(
                      '긴급 연락처',
                      Icons.contact_phone,
                      Colors.teal.shade100,
                      () {
                        // 긴급 연락처 화면으로 이동
                        Get.to(() => const EmergencyContactsView());
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: '지도',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: '메시지',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
        onTap: (index) {
          // 탭에 따른 화면 이동 로직 구현
          switch (index) {
            case 0: // 홈
              // 이미 홈 화면에 있으므로 아무 작업 안함
              break;
            case 1: // 지도
              Get.toNamed('/map');
              break;
            case 2: // 메시지
              // 아직 구현되지 않음
              break;
            case 3: // 설정
              Get.to(() => const SettingsView());
              break;
          }
        },
      ),
    );
  }

  Widget _buildFeatureCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.grey.shade800,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
