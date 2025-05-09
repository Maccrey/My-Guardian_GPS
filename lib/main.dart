import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/auth_service.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/forgot_password_view.dart';
import 'views/home_view.dart';
import 'views/emergency_guide_view.dart';
import 'views/emergency_contacts_view.dart';
import 'views/privacy_policy_view.dart';
import 'views/terms_of_service_view.dart';
import 'views/app_info_view.dart';
import 'services/emergency_contact_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'views/map_view.dart';
import 'views/settings/settings_view.dart';
import 'services/settings_service.dart';

// SharedPreferences가 초기화되지 않은 경우에도 앱이 작동하도록 기본값으로 사용할 플래그
bool isSharedPreferencesAvailable = false;
// 전역 SharedPreferences 인스턴스 - 앱 전체에서 접근 가능
SharedPreferences? prefsInstance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 로드
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('✅ .env 파일 로드 성공');
  } catch (e) {
    debugPrint('❌ .env 파일 로드 실패: $e');
    // 오류 상세 정보 출력
    FlutterError.dumpErrorToConsole(
      FlutterErrorDetails(
        exception: e,
        stack: StackTrace.current,
        library: 'main.dart',
        context: ErrorDescription('.env 파일 로드 중 오류'),
      ),
    );
  }

  try {
    // SharedPreferences 초기화 시도
    prefsInstance = await SharedPreferences.getInstance();
    isSharedPreferencesAvailable = true;
    debugPrint(
        '✅ 앱 시작 시 SharedPreferences 초기화됨: 키 목록=${prefsInstance?.getKeys()}, 인스턴스 정보=${prefsInstance.toString()}');
  } catch (e) {
    isSharedPreferencesAvailable = false;
    debugPrint('❌ SharedPreferences 초기화 오류: $e');
    debugPrint('❌ 오류 상세 정보: ${e.toString()}');

    // Flutter 에러 정보 출력
    FlutterError.dumpErrorToConsole(
      FlutterErrorDetails(
        exception: e,
        stack: StackTrace.current,
        library: 'main.dart',
        context: ErrorDescription('SharedPreferences 초기화 중 오류'),
      ),
    );

    debugPrint('⚠️ 메모리 모드로 작동됩니다. 앱을 다시 시작하면 문제가 해결될 수 있습니다.');
  }

  // SettingsService 초기화
  await SettingsService.getInstance();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 서비스 초기화
    Get.put(AuthService());
    // 긴급 연락처 서비스 초기화 - SharedPreferences 상태에 따라 메모리 모드 설정
    Get.put(EmergencyContactService(
      useMemoryOnly: !isSharedPreferencesAvailable,
      prefs: prefsInstance,
    ));

    // 위치 서비스 초기화 - 안전하게 초기화
    try {
      // 이미 등록되어 있지 않은 경우에만 등록
      if (!Get.isRegistered<LocationService>()) {
        Get.put(LocationService());
        debugPrint('✅ LocationService 초기화 성공');
      }
    } catch (e) {
      debugPrint('⚠️ LocationService 초기화 실패: $e');
    }

    // 알림 서비스 초기화
    try {
      // NotificationService 초기화
      NotificationService.getInstance().then((service) {
        if (!Get.isRegistered<NotificationService>()) {
          Get.put(service);
        }
        debugPrint('✅ NotificationService 초기화 성공');
      });
    } catch (e) {
      debugPrint('⚠️ NotificationService 초기화 실패: $e');
    }

    return GetMaterialApp(
      title: '모던 로그인',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system, // 시스템 설정 기본값
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const LoginView()),
        GetPage(name: '/register', page: () => const RegisterView()),
        GetPage(
            name: '/forgot-password', page: () => const ForgotPasswordView()),
        GetPage(name: '/home', page: () => const HomeView()),
        GetPage(
            name: '/emergency-guide', page: () => const EmergencyGuideView()),
        GetPage(
            name: '/emergency-contacts',
            page: () => const EmergencyContactsView()),
        GetPage(
          name: '/settings',
          page: () => const SettingsView(),
        ),
        GetPage(
          name: '/privacy-policy',
          page: () => const PrivacyPolicyView(),
        ),
        GetPage(
          name: '/terms-of-service',
          page: () => const TermsOfServiceView(),
        ),
        GetPage(
          name: '/app-info',
          page: () => const AppInfoView(),
        ),
        // IMPORTANT: MapView는 지도 화면을 담당하는 중요 컴포넌트입니다.
        // 경로를 변경하거나 다른 구성으로 변경하지 마세요.
        GetPage(name: '/map', page: () => MapView()),
      ],
    );
  }
}
