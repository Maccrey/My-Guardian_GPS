import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/settings_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({Key? key}) : super(key: key);

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late SettingsService settingsService;
  LocationService? locationService;
  NotificationService? notificationService;
  final RxBool _isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    settingsService = await SettingsService.getInstance();

    try {
      // LocationService는 선택적으로 가져옴 (없을 수도 있음)
      if (Get.isRegistered<LocationService>()) {
        locationService = Get.find<LocationService>();
        debugPrint('✅ LocationService 찾음');
      } else {
        debugPrint('⚠️ LocationService를 찾을 수 없음');
      }

      // NotificationService 가져오기
      if (Get.isRegistered<NotificationService>()) {
        notificationService = Get.find<NotificationService>();
        debugPrint('✅ NotificationService 찾음');
      } else {
        // 등록되지 않은 경우 초기화
        notificationService = await NotificationService.getInstance();
        Get.put(notificationService!);
        debugPrint('✅ NotificationService 등록 완료');
      }
    } catch (e) {
      debugPrint('⚠️ 서비스 로드 오류: $e');
    }

    _isLoading.value = false;
  }

  void _applyRecommendedSettings(String settingType) async {
    await settingsService.applyRecommendedSettings(settingType);

    // 위치 서비스 설정 변경 시 LocationService에도 반영
    if (locationService != null) {
      locationService!
          .setLocationServiceEnabled(settingsService.isLocationEnabled.value);
    }

    // 알림 설정 변경 시 NotificationService에도 반영
    if (notificationService != null) {
      await notificationService!
          .setNotificationEnabled(settingsService.isNotificationEnabled.value);
    }

    Get.snackbar(
      '설정 적용됨',
      '$settingType 추천 설정이 적용되었습니다',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green.shade100,
      duration: const Duration(seconds: 2),
    );
  }

  // 위치 서비스 토글 메서드
  void _toggleLocationService(bool value) {
    settingsService.isLocationEnabled.value = value;
    settingsService.saveSettings();

    // LocationService에도 상태 반영 (있는 경우에만)
    if (locationService != null) {
      locationService!.setLocationServiceEnabled(value);
    }

    Get.snackbar(
      '위치 서비스 ${value ? '활성화' : '비활성화'}됨',
      value ? '지도 및 위치 기능이 활성화되었습니다' : '지도 및 위치 기능이 비활성화되었습니다',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
    );
  }

  // 알림 토글 메서드
  void _toggleNotification(bool value) async {
    settingsService.isNotificationEnabled.value = value;
    settingsService.saveSettings();

    // NotificationService에 상태 반영 (있는 경우에만)
    if (notificationService != null) {
      await notificationService!.setNotificationEnabled(value);
    } else {
      debugPrint('⚠️ NotificationService가 초기화되지 않아 알림 설정을 적용할 수 없습니다.');
    }

    Get.snackbar(
      '알림 ${value ? '활성화' : '비활성화'}됨',
      value ? '앱 알림이 활성화되었습니다' : '앱 알림이 비활성화되었습니다',
      snackPosition: SnackPosition.BOTTOM,
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
                  onChanged: (value) async {
                    await settingsService.toggleTheme();
                    Get.snackbar(
                      '테마 변경됨',
                      settingsService.isDarkMode.value
                          ? '다크 모드가 활성화되었습니다'
                          : '라이트 모드가 활성화되었습니다',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 1),
                      backgroundColor: Get.isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      colorText: Get.isDarkMode ? Colors.white : Colors.black,
                    );
                  },
                  secondary: Icon(
                    settingsService.isDarkMode.value
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: settingsService.isDarkMode.value
                        ? Colors.amber
                        : Colors.blue,
                  ),
                )),
            const Divider(),

            // 설정 카테고리: 개인정보 및 보안
            _buildCategoryHeader('개인정보 및 보안'),
            Obx(() => SwitchListTile(
                  title: const Text('위치 서비스'),
                  subtitle: const Text('지도 및 위치 기능을 사용합니다'),
                  value: settingsService.isLocationEnabled.value,
                  onChanged: _toggleLocationService,
                  secondary: Icon(
                    Icons.location_on,
                    color: settingsService.isLocationEnabled.value
                        ? Colors.blue
                        : Colors.grey,
                  ),
                )),
            Obx(() => SwitchListTile(
                  title: const Text('알림'),
                  subtitle: const Text('앱 알림을 허용합니다'),
                  value: settingsService.isNotificationEnabled.value,
                  onChanged: _toggleNotification,
                  secondary: Icon(
                    Icons.notifications,
                    color: settingsService.isNotificationEnabled.value
                        ? Colors.blue
                        : Colors.grey,
                  ),
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
                Get.toNamed('/privacy-policy');
              },
            ),
            ListTile(
              title: const Text('이용약관'),
              leading: const Icon(Icons.description),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // 이용약관.페이지로 이동하는 로직
                Get.toNamed('/terms-of-service');
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
                          onPressed: () async {
                            settingsService.resetSettings();

                            // LocationService에도 상태 반영 (있는 경우에만)
                            if (locationService != null) {
                              locationService!.setLocationServiceEnabled(
                                  settingsService.isLocationEnabled.value);
                            }

                            // NotificationService에도 상태 반영 (있는 경우에만)
                            if (notificationService != null) {
                              await notificationService!.setNotificationEnabled(
                                  settingsService.isNotificationEnabled.value);
                            }

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
