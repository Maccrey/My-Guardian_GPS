import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:workmanager/workmanager.dart';

import 'services/auth_service.dart';
import 'services/message_service.dart';
import 'services/home_arrival_service.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/forgot_password_view.dart';
import 'views/home_view.dart';
import 'views/emergency_guide_view.dart';
import 'views/emergency_contacts_view.dart';
import 'views/privacy_policy_view.dart';
import 'views/terms_of_service_view.dart';
import 'views/app_info_view.dart';
import 'views/sos_view.dart';
import 'services/emergency_contact_service.dart';
import 'services/location_service.dart';
import 'views/map_view.dart';
import 'views/settings/settings_view.dart';
import 'utils/url_handler.dart';
import 'views/profile/profile_edit_view.dart';
import 'views/home_arrival_view.dart';
import 'services/location_sharing_service.dart';
import 'controllers/location_sharing_controller.dart';
import 'views/location_sharing/emergency_contact_location_view.dart';
import 'views/location_sharing/location_tracking_view.dart';
import 'views/location_sharing/user_search_location_view.dart';
import 'views/user_search_contact_view.dart';
import 'services/biometric_service.dart';
import 'views/app_lock_screen.dart';
import 'services/notification_service.dart';
import 'services/background_location_service.dart';
import 'services/background_task_service.dart';

import 'firebase_options.dart';

// SharedPreferences 초기화 상태를 추적하는 플래그
bool isSharedPreferencesAvailable = false;
// 전역 SharedPreferences 인스턴스 - 앱 전체에서 접근 가능
SharedPreferences? prefsInstance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 화면 방향을 세로(Portrait)로 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // 위쪽 세로
    DeviceOrientation.portraitDown, // 아래쪽 세로 (원하면 뺄 수도 있음)
  ]);

  // .env 파일 로드 (API 키 등 환경변수)
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ .env 파일 로드 성공');
  } catch (e) {
    debugPrint('⚠️ .env 파일 로드 실패: $e');
    // 기본 .env 파일이 없으면 빈 환경으로 초기화
    await dotenv.load(fileName: "nonexistent.env").catchError((_) {
      // 빈 환경 초기화
      dotenv.env['GOOGLE_MAPS_API_KEY'] = 'dummy_key_for_development';
      debugPrint('⚠️ 더미 API 키로 초기화됨');
    });
  }

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // LocationSharingService 직접 등록 (최우선)
  Get.put(LocationSharingService(), permanent: true);

  // 필요한 서비스 초기화
  await initServices();

  // 앱 실행
  runApp(const MyApp());
}

/// 앱에 필요한 서비스 초기화
Future<void> initServices() async {
  try {
    // Workmanager 초기화 (백그라운드 작업용)
    await Workmanager().initialize(callbackDispatcher);

    // 필수 서비스 등록 (의존성 순서대로)
    debugPrint('🔄 기본 서비스 초기화 시작...');
    Get.put(AuthService(), permanent: true);
    Get.put(LocationService(), permanent: true);
    Get.put(EmergencyContactService(), permanent: true);
    Get.put(MessageService(), permanent: true);

    // NotificationService 초기화 (싱글톤)
    await NotificationService.getInstance();

    // 백그라운드 서비스 초기화
    final backgroundLocationService = BackgroundLocationService.instance;
    await backgroundLocationService.init();

    // HomeArrivalService 초기화 및 보류 중인 알림 확인
    final homeArrivalService = await HomeArrivalService.getInstance();

    // 보류 중인 귀가 알림 확인 및 처리
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 프레임 렌더링 후 실행하여 GetX가 완전히 초기화된 후 실행되도록 함
      await homeArrivalService.checkPendingArrivalNotification();
    });

    debugPrint('✅ 서비스 초기화 완료');
  } catch (e) {
    debugPrint('❌ 서비스 초기화 중 오류 발생: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // LocationSharingService 확인 및 강제 등록
    if (!Get.isRegistered<LocationSharingService>()) {
      debugPrint('⚠️ MyApp: LocationSharingService 재등록 시도');
      Get.put(LocationSharingService(), permanent: true);
    }

    // LocationSharingController 확인 및 강제 등록
    if (!Get.isRegistered<LocationSharingController>()) {
      debugPrint('⚠️ MyApp: LocationSharingController 등록 시도');
      Get.put(LocationSharingController(), permanent: true);
    }

    // URL 핸들러 초기화
    if (!kIsWeb) {
      Future.delayed(const Duration(milliseconds: 500), () {
        // UrlHandler.initialize(); // 구버전 방식
        // 새로운 방식으로 URL 핸들러 초기화
        final urlHandler = UrlHandler();
        urlHandler.init();
      });
    }

    // 앱 잠금 상태 확인 및 생체인증 서비스 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // 생체인증 서비스 먼저 초기화
        BiometricService biometricService;
        if (!Get.isRegistered<BiometricService>()) {
          debugPrint('👆 BiometricService 초기화 시작...');
          biometricService = BiometricService();
          Get.put<BiometricService>(biometricService, permanent: true);
          debugPrint('✅ BiometricService 초기화 성공');
        } else {
          biometricService = Get.find<BiometricService>();
          debugPrint('✅ BiometricService 이미 등록됨');
        }

        // 생체인증 상태 새로고침 (앱 재시작 시 설정 로드)
        await biometricService.refreshBiometricStatus();
        debugPrint(
            '✅ 생체인증 상태 새로고침 완료: 앱 잠금=${biometricService.isAppLocked.value}');

        // 이미 AuthService가 초기화되어 있는지 확인
        if (Get.isRegistered<AuthService>()) {
          final authService = Get.find<AuthService>();

          // 로그인 상태이고 앱 잠금이 활성화된 경우 잠금 화면으로 이동
          if (authService.isAuthenticated &&
              biometricService.isAppLocked.value) {
            debugPrint('🔒 인증된 사용자 + 앱 잠금 활성화: 잠금 화면으로 이동');
            Get.to(() => const AppLockScreen());
          }
        }
      } catch (e) {
        debugPrint('❌ 생체인증 및 앱 잠금 초기화 오류: $e');
      }
    });
  }

  @override
  void dispose() {
    // URL 핸들러 리소스 해제 (더 이상 정적 메서드가 아님)
    // UrlHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 서비스 초기화
    // 먼저 AuthService 초기화해야 다른 서비스에서 사용 가능
    try {
      if (!Get.isRegistered<AuthService>()) {
        debugPrint('🔑 AuthService 초기화 시작...');
        final authService = AuthService();
        Get.put(authService, permanent: true);

        // 초기화 확인
        final uid = authService.uid;
        final user = authService.currentUser;
        debugPrint('✅ AuthService 초기화 성공 - 현재 UID: ${uid ?? '로그인되지 않음'}');
        debugPrint('👤 현재 사용자: ${user != null ? '로그인됨' : '로그인되지 않음'}');
      }
    } catch (e) {
      debugPrint('⚠️ AuthService 초기화 오류: $e');
      debugPrint('⚠️ 오류 스택: ${StackTrace.current}');
    }

    // 메시지 서비스 초기화
    try {
      if (!Get.isRegistered<MessageService>()) {
        debugPrint('💬 MessageService 초기화 시작...');
        Get.put(MessageService(), permanent: true);
        debugPrint('✅ MessageService 초기화 성공');
      }
    } catch (e) {
      debugPrint('⚠️ MessageService 초기화 오류: $e');
    }

    // 위치 서비스 초기화
    try {
      if (!Get.isRegistered<LocationService>()) {
        debugPrint('🗺️ LocationService 초기화 시작...');
        Get.put(LocationService(), permanent: true);
        debugPrint('✅ LocationService 초기화 성공');
      }
    } catch (e) {
      debugPrint('⚠️ LocationService 초기화 오류: $e');
    }

    // 비상 연락처 서비스 초기화
    try {
      if (!Get.isRegistered<EmergencyContactService>()) {
        debugPrint('☎️ EmergencyContactService 초기화 시작...');
        Get.put(EmergencyContactService(), permanent: true);
        debugPrint('✅ EmergencyContactService 초기화 성공');
      }
    } catch (e) {
      debugPrint('⚠️ EmergencyContactService 초기화 오류: $e');
    }

    // 앱 시작 시 저장된 알림 확인
    try {
      // 앱이 재시작될 때 발송되지 못한 귀가 알림이 있는지 확인
      HomeArrivalService.getInstance().then((service) {
        service.checkPendingArrivalNotification();
      });
      debugPrint('✅ 귀가 알림 확인 시작됨');
    } catch (e) {
      debugPrint('⚠️ 귀가 알림 확인 오류: $e');
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'), // 한국어
        Locale('en', 'US'), // 영어
      ],
      locale: const Locale('ko', 'KR'), // 기본 로케일 설정
      initialRoute: Get.find<AuthService>().isAuthenticated ? '/home' : '/',
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
        GetPage(
          name: '/sos',
          page: () => const SOSView(),
        ),
        // IMPORTANT: MapView는 지도 화면을 담당하는 중요 컴포넌트입니다.
        // 경로를 변경하거나 다른 구성으로 변경하지 마세요.
        GetPage(name: '/map', page: () => MapView()),
        // 프로필 편집 페이지 라우트
        GetPage(
          name: '/profile-edit',
          page: () => const ProfileEditView(),
          binding: ProfileEditBinding(),
        ),
        // 귀가 알림 페이지 라우트
        GetPage(
          name: '/home-arrival',
          page: () => const HomeArrivalView(),
        ),
        // 위치 공유 화면 라우트
        GetPage(
          name: '/location-sharing',
          page: () => EmergencyContactLocationView(),
        ),
        // 사용자 검색 및 위치 공유 화면 라우트
        GetPage(
          name: '/user-search-location',
          page: () => const UserSearchLocationView(),
          binding: BindingsBuilder(() {
            Get.put(LocationSharingService());
          }),
        ),
        // 위치 추적 화면 라우트
        GetPage(
          name: '/location-tracking',
          page: () => const LocationTrackingView(),
          transition: Transition.rightToLeft,
        ),
        // 앱 사용자 검색 및 긴급 연락처 추가 화면 라우트
        GetPage(
          name: '/user-search-contact',
          page: () => const UserSearchContactView(),
          binding: BindingsBuilder(() {
            Get.put(EmergencyContactService());
          }),
        ),
        GetPage(name: '/app-lock', page: () => const AppLockScreen()),
      ],
    );
  }
}

// 미사용 함수이므로 주석 처리
/*
void initServices() async {
  debugPrint('🚀 서비스 초기화 시작...');

  // 설정 서비스 초기화 (반드시 SharedPreferences 이후에 초기화)
  if (isSharedPreferencesAvailable) {
    try {
      final settingsService = SettingsService();
      await settingsService.initialize(prefsInstance!);
      Get.put(settingsService);
      debugPrint('✅ SettingsService 초기화 성공');
    } catch (e) {
      debugPrint('⚠️ SettingsService 초기화 실패: $e');
    }
  }

  // 인증 서비스 초기화
  try {
    final authService = AuthService();
    await authService.init();
    Get.put(authService);
    debugPrint('✅ AuthService 초기화 성공');
  } catch (e) {
    debugPrint('⚠️ AuthService 초기화 실패: $e');
  }

  // 메시지 서비스 초기화
  try {
    final messageService = MessageService();
    await messageService.init();
    Get.put(messageService);
    debugPrint('✅ MessageService 초기화 성공');
  } catch (e) {
    debugPrint('⚠️ MessageService 초기화 실패: $e');
  }

  // 위치 서비스 초기화
  try {
    final locationService = LocationService();
    await locationService.init();
    Get.put(locationService);
    debugPrint('✅ LocationService 초기화 성공');
  } catch (e) {
    debugPrint('⚠️ LocationService 초기화 실패: $e');
  }

  // 비상 연락처 서비스 초기화
  try {
    final emergencyContactService = EmergencyContactService();
    await emergencyContactService.init();
    Get.put(emergencyContactService);
    debugPrint('✅ EmergencyContactService 초기화 성공');
  } catch (e) {
    debugPrint('⚠️ EmergencyContactService 초기화 실패: $e');
  }

  // 이미지 캐시 서비스 초기화
  try {
    final imageCacheService = ImageCacheService();
    await imageCacheService.init();
    Get.put(imageCacheService);
    debugPrint('✅ ImageCacheService 초기화 성공');
  } catch (e) {
    debugPrint('⚠️ ImageCacheService 초기화 실패: $e');
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
}
*/
