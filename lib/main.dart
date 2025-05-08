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

void main() async {
  // Flutter 엔진 초기화 - SharedPreferences가 정상 작동하도록 함
  WidgetsFlutterBinding.ensureInitialized();

  // SharedPreferences 초기화 확인
  final prefs = await SharedPreferences.getInstance();
  debugPrint('앱 시작 시 SharedPreferences 초기화됨: ${prefs.getKeys()}');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 서비스 초기화 - 앱 시작 시 서비스를
    final authService = Get.put(AuthService());
    final emergencyContactService = Get.put(EmergencyContactService());

    // 서비스 초기화 상태를 로그로 기록
    debugPrint(
        'EmergencyContactService 초기화됨: ${emergencyContactService.hashCode}');

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
