import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import '../views/messages/shared_location_view.dart';

/// Google Maps URL 등 딥링크 및 URL 처리를 위한 유틸리티 클래스
class UrlHandler {
  static final UrlHandler _instance = UrlHandler._internal();
  factory UrlHandler() => _instance;
  UrlHandler._internal();

  // 딥링크 리스너
  StreamSubscription? _linkSubscription;
  final AppLinks _appLinks = AppLinks();

  /// URL 처리 시작
  Future<void> init() async {
    // 앱이 이미 실행 중일 때 딥링크를 받았을 경우
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        debugPrint('✅ 딥링크 수신 (스트림): ${uri.toString()}');
        _handleLink(uri);
      }
    }, onError: (error) {
      debugPrint('❌ 딥링크 오류: $error');
    });

    // 앱이 종료된 상태에서 딥링크로 시작된 경우
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('✅ 초기 딥링크 수신: ${initialUri.toString()}');
        _handleLink(initialUri);
      }
    } catch (e) {
      debugPrint('❌ 초기 딥링크 오류: $e');
    }
  }

  /// 딥링크 처리
  void _handleLink(Uri uri) {
    try {
      final String path = uri.path;
      final Map<String, String> queryParams = uri.queryParameters;

      debugPrint('📌 딥링크 경로: $path, 쿼리: $queryParams');

      // 경로에 따라 다른 화면으로 라우팅
      if (path.contains('/emergency')) {
        // 긴급 상황 요청 화면으로 이동
        final userId = queryParams['userId'];
        if (userId != null) {
          Get.toNamed('/emergency-request', arguments: {'userId': userId});
        }
      } else if (path.contains('/location')) {
        // 위치 공유 화면으로 이동
        final userId = queryParams['userId'];
        if (userId != null) {
          Get.toNamed('/location-tracking', arguments: {'userId': userId});
        }
      } else if (path.contains('/message')) {
        // 메시지 화면으로 이동
        final senderId = queryParams['senderId'];
        if (senderId != null) {
          Get.toNamed('/messages', arguments: {'senderId': senderId});
        }
      }
    } catch (e) {
      debugPrint('❌ 딥링크 처리 오류: $e');
    }
  }

  /// 정리
  void dispose() {
    _linkSubscription?.cancel();
  }

  /// Google Maps URL 문자열 처리
  static void handleUrl(String url) {
    try {
      if (_isGoogleMapsUrl(url)) {
        SharedLocationView.openFromMapsUrl(url);
        return;
      }

      // URL이 유효하면 브라우저에서 열기
      if (url.startsWith('http://') || url.startsWith('https://')) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('⚠️ URL 처리 중 오류 발생: $e');
    }
  }

  /// Google Maps URL인지 확인
  static bool _isGoogleMapsUrl(String url) {
    try {
      final Uri uri = Uri.parse(url);
      return (uri.host.contains('maps.google.com') ||
              uri.host.contains('google.com/maps')) &&
          uri.queryParameters.containsKey('q');
    } catch (e) {
      return false;
    }
  }

  /// 클립보드 확인
  static Future<void> checkClipboard() async {
    try {
      final ClipboardData? clipboardData =
          await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        final text = clipboardData.text!;

        // Google Maps URL 확인
        if (_isGoogleMapsUrl(text)) {
          // 사용자에게 앱에서 열기 옵션 제공
          _showOpenInAppDialog(text);
        }
      }
    } catch (e) {
      debugPrint('⚠️ 클립보드 확인 오류: $e');
    }
  }

  /// 앱에서 열기 다이얼로그
  static void _showOpenInAppDialog(String url) {
    Get.dialog(
      AlertDialog(
        title: const Text('지도 링크 감지'),
        content: const Text('Google Maps 링크가 감지되었습니다. Watch Over 앱에서 열겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              handleUrl(url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('앱에서 열기'),
          ),
        ],
      ),
    );
  }
}
