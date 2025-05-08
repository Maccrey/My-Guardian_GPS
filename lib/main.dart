import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/auth_service.dart';
import 'services/emergency_contact_service.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/forgot_password_view.dart';
import 'views/home_view.dart';
import 'views/emergency_contacts_view.dart';
import 'views/emergency_guide_view.dart';

// SharedPreferences가 초기화되지 않은 경우에도 앱이 작동하도록 기본값으로 사용할 플래그
bool isSharedPreferencesAvailable = false;
// 전역 SharedPreferences 인스턴스 - 앱 전체에서 접근 가능
SharedPreferences? prefsInstance;

void main() async {
  // Flutter 엔진 초기화 - SharedPreferences가 정상 작동하도록 함
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 서비스 초기화 - 앱 시작 시 서비스를
    final authService = Get.put(AuthService());
    final emergencyContactService = Get.put(EmergencyContactService(
      useMemoryOnly: !isSharedPreferencesAvailable,
      prefs: prefsInstance,
    ));

    // 서비스 초기화 상태를 로그로 기록
    debugPrint(
        'EmergencyContactService 초기화됨: ${emergencyContactService.hashCode}, 메모리 모드: ${!isSharedPreferencesAvailable}');

    return GetMaterialApp(
      title: '모던 로그인',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const LoginView()),
        GetPage(name: '/register', page: () => const RegisterView()),
        GetPage(
            name: '/forgot-password', page: () => const ForgotPasswordView()),
        GetPage(name: '/home', page: () => const HomeView()),
        GetPage(
            name: '/emergency-contacts',
            page: () => const EmergencyContactsView()),
        // ********************************************
        // ****** 보호된 코드: 절대 수정하지 마세요 ******
        // ****** PROTECTED CODE: DO NOT MODIFY ******
        GetPage(
            name: '/emergency-guide', page: () => const EmergencyGuideView()),
        // ********************************************
      ],
    );
  }
}
