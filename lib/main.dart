import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/auth_service.dart';
import 'services/message_service.dart';
import 'services/image_cache_service.dart';
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
import 'services/notification_service.dart';
import 'views/map_view.dart';
import 'views/settings/settings_view.dart';
import 'services/settings_service.dart';
import 'utils/url_handler.dart';
import 'views/profile_edit_view.dart';
import 'services/map_api_service.dart';
import 'views/home_arrival_view.dart';
import 'services/location_sharing_service.dart';
import 'controllers/location_sharing_controller.dart';
import 'views/location_sharing/emergency_contact_location_view.dart';
import 'views/location_sharing/location_tracking_view.dart';
import 'views/location_sharing/user_search_location_view.dart';
import 'views/user_search_contact_view.dart';

import 'firebase_options.dart';

// SharedPreferences 초기화 상태를 추적하는 플래그
bool isSharedPreferencesAvailable = false;
// 전역 SharedPreferences 인스턴스 - 앱 전체에서 접근 가능
SharedPreferences? prefsInstance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase 초기화 성공');

    // Firebase 인스턴스 확인 (테스트용)
    final firebaseApp = Firebase.app();
    debugPrint('✅ Firebase 앱 이름: ${firebaseApp.name}');
    debugPrint('✅ Firebase 프로젝트 ID: ${firebaseApp.options.projectId}');

    // Firestore와 Auth 연결 테스트
    debugPrint('📡 Firebase 서비스 연결 테스트 중...');
  } catch (e) {
    debugPrint('❌ Firebase 초기화 오류: $e');
    debugPrint('❌ Firebase 오류 스택: ${StackTrace.current}');

    // 오류 상세 정보 출력
    FlutterError.dumpErrorToConsole(
      FlutterErrorDetails(
        exception: e,
        stack: StackTrace.current,
        library: 'main.dart',
        context: ErrorDescription('Firebase 초기화 중 오류'),
      ),
    );

    debugPrint('⚠️ Firebase가 초기화되지 않았습니다. 일부 기능이 제한될 수 있습니다.');
  }
  // Firebase 초기화 코드 제거 - 테스트를 위해

  // 백그라운드 오디오 초기화
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.gps_search.sos.channel.audio',
      androidNotificationChannelName: 'SOS 알림',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    );
    debugPrint('✅ 백그라운드 오디오 서비스 초기화 성공');
  } catch (e) {
    debugPrint('❌ 백그라운드 오디오 서비스 초기화 실패: $e');
  }

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

  // Google Maps API 키 설정 - 플랫폼별 처리
  try {
    // 플랫폼에 맞게 API 키 설정
    final result = await MapApiService.setGoogleMapsApiKeyForPlatform();
    if (result) {
      debugPrint('✅ Google Maps API 키 설정 완료');
    } else {
      debugPrint('⚠️ Google Maps API 키 설정 실패');
    }
  } catch (e) {
    debugPrint('❌ Google Maps API 키 설정 중 오류: $e');
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

  // 백그라운드에서 도착 시 알림을 위한 HomeArrivalService 초기화
  try {
    await HomeArrivalService.getInstance();
    debugPrint('✅ HomeArrivalService 초기화 성공');
  } catch (e) {
    debugPrint('❌ HomeArrivalService 초기화 오류: $e');
  }

  // 위치 공유 서비스 및 컨트롤러 초기화
  Get.put(LocationSharingService());
  Get.put(LocationSharingController());

  runApp(const MyApp());
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

    // URL 핸들러 초기화
    if (!kIsWeb) {
      Future.delayed(const Duration(milliseconds: 500), () {
        // UrlHandler.initialize(); // 구버전 방식
        // 새로운 방식으로 URL 핸들러 초기화
        final urlHandler = UrlHandler();
        urlHandler.init();
      });
    }
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
        final messageService = Get.put(MessageService(), permanent: true);
        debugPrint('✅ MessageService 초기화 성공');
      }
    } catch (e) {
      debugPrint('⚠️ MessageService 초기화 오류: $e');
    }

    // 위치 서비스 초기화
    try {
      if (!Get.isRegistered<LocationService>()) {
        debugPrint('🗺️ LocationService 초기화 시작...');
        final locationService = Get.put(LocationService(), permanent: true);
        debugPrint('✅ LocationService 초기화 성공');
      }
    } catch (e) {
      debugPrint('⚠️ LocationService 초기화 오류: $e');
    }

    // 비상 연락처 서비스 초기화
    try {
      if (!Get.isRegistered<EmergencyContactService>()) {
        debugPrint('☎️ EmergencyContactService 초기화 시작...');
        final emergencyContactService =
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
