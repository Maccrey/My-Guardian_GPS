import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/settings_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late SettingsService settingsService;
  final RxBool _isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _initSettingsService();
  }

  Future<void> _initSettingsService() async {
    settingsService = await SettingsService.getInstance();
    _isLoading.value = false;
  }

  void _applyRecommendedSettings(String settingType) async {
    await settingsService.applyRecommendedSettings(settingType);
    Get.snackbar(
      '설정 적용됨',
      '$settingType 추천 설정이 적용되었습니다',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade100,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.recommend),
            tooltip: '추천 설정',
            onSelected: _applyRecommendedSettings,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'privacy',
                child: ListTile(
                  leading: Icon(Icons.security),
                  title: Text('개인정보 보호 중심'),
                  subtitle: Text('위치, 알림 끄기, 생체인증 사용'),
                ),
              ),
              const PopupMenuItem(
                value: 'performance',
                child: ListTile(
                  leading: Icon(Icons.speed),
                  title: Text('성능 중심'),
                  subtitle: Text('데이터 절약 모드 켜기'),
                ),
              ),
              const PopupMenuItem(
                value: 'balanced',
                child: ListTile(
                  leading: Icon(Icons.balance),
                  title: Text('균형 설정'),
                  subtitle: Text('편의성과 보안의 균형'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Obx(() {
        if (_isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          children: [
            // 설정 카테고리: 앱 설정
            _buildCategoryHeader('앱 설정'),
            Obx(() => SwitchListTile(
                  title: const Text('다크 모드'),
                  subtitle: const Text('어두운 테마로 사용합니다'),
                  value: settingsService.isDarkMode.value,
                  onChanged: (value) {
                    settingsService.isDarkMode.value = value;
                    settingsService.saveSettings();
                  },
                  secondary: const Icon(Icons.dark_mode),
                )),
            const Divider(),

            // 설정 카테고리: 개인정보 및 보안
            _buildCategoryHeader('개인정보 및 보안'),
            Obx(() => SwitchListTile(
                  title: const Text('위치 서비스'),
                  subtitle: const Text('지도 및 위치 기능을 사용합니다'),
                  value: settingsService.isLocationEnabled.value,
                  onChanged: (value) {
                    settingsService.isLocationEnabled.value = value;
                    settingsService.saveSettings();
                  },
                  secondary: const Icon(Icons.location_on),
                )),
            Obx(() => SwitchListTile(
                  title: const Text('알림'),
                  subtitle: const Text('앱 알림을 허용합니다'),
                  value: settingsService.isNotificationEnabled.value,
                  onChanged: (value) {
                    settingsService.isNotificationEnabled.value = value;
                    settingsService.saveSettings();
                  },
                  secondary: const Icon(Icons.notifications),
                )),
            Obx(() => SwitchListTile(
                  title: const Text('생체 인증'),
                  subtitle: const Text('앱 잠금에 생체 인증을 사용합니다'),
                  value: settingsService.isBiometricEnabled.value,
                  onChanged: (value) {
                    settingsService.isBiometricEnabled.value = value;
                    settingsService.saveSettings();
                  },
                  secondary: const Icon(Icons.fingerprint),
                )),
            const Divider(),

            // 설정 카테고리: 데이터 및 저장소
            _buildCategoryHeader('데이터 및 저장소'),
            Obx(() => SwitchListTile(
                  title: const Text('데이터 절약 모드'),
                  subtitle: const Text('모바일 데이터 사용량을 줄입니다'),
                  value: settingsService.isDataSavingEnabled.value,
                  onChanged: (value) {
                    settingsService.isDataSavingEnabled.value = value;
                    settingsService.saveSettings();
                  },
                  secondary: const Icon(Icons.data_saver_off),
                )),
            const Divider(),

            // 정보 섹션
            ListTile(
              title: const Text('앱 정보'),
              leading: const Icon(Icons.info),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // 앱 정보 페이지로 이동하는 로직
              },
            ),
            ListTile(
              title: const Text('개인정보 처리방침'),
              leading: const Icon(Icons.privacy_tip),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // 개인정보 처리방침 페이지로 이동하는 로직
              },
            ),
            ListTile(
              title: const Text('이용약관'),
              leading: const Icon(Icons.description),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // 이용약관 페이지로 이동하는 로직
              },
            ),

            // 설정 초기화 버튼
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('설정 초기화'),
                      content: const Text('모든 설정을 기본값으로 초기화하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () {
                            settingsService.resetSettings();
                            Navigator.of(context).pop();
                            Get.snackbar(
                              '설정 초기화됨',
                              '모든 설정이 기본값으로 초기화되었습니다',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.blue.shade100,
                            );
                          },
                          child: const Text('초기화'),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                ),
                child: const Text('모든 설정 초기화'),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}
