import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:uni_links/uni_links.dart';
import 'package:url_launcher/url_launcher.dart';
import '../views/messages/shared_location_view.dart';

/// Google Maps URL 등 딥링크 및 URL 처리를 위한 유틸리티 클래스
class UrlHandler {
  static StreamSubscription? _linkSubscription;
  static bool _initialURILinkHandled = false;

  /// URL 처리 시작
  static void initialize() {
    // 앱 시작 시 딥링크 처리
    _initURIHandler();
    // 앱 실행 중 딥링크 처리
    _incomingLinkHandler();
  }

  /// 앱 시작 시 딥링크 초기 처리
  static Future<void> _initURIHandler() async {
    if (!_initialURILinkHandled) {
      _initialURILinkHandled = true;
      try {
        // 앱 시작 시 초기 URI 확인
        final initialURI = await getInitialUri();
        if (initialURI != null) {
          debugPrint('🔗 앱 시작 시 딥링크 감지: $initialURI');
          handleUri(initialURI);
        }
      } on PlatformException {
        debugPrint('⚠️ 딥링크 초기화 오류');
      }
    }
  }

  /// 앱 실행 중 딥링크 처리
  static void _incomingLinkHandler() {
    // 딥링크 스트림 리스닝
    _linkSubscription = uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        debugPrint('🔗 앱 실행 중 딥링크 감지: $uri');
        handleUri(uri);
      }
    }, onError: (err) {
      debugPrint('⚠️ 딥링크 스트림 오류: $err');
    });
  }

  /// URI 처리 로직
  static void handleUri(Uri uri) {
    try {
      // 구글 지도 링크인 경우
      if (_isGoogleMapsUrl(uri.toString())) {
        // 앱 내에서 지도 열기
        SharedLocationView.openFromMapsUrl(uri.toString());
        return;
      }

      // 다른 유형의 URL 처리 추가 가능
    } catch (e) {
      debugPrint('⚠️ URI 처리 중 오류 발생: $e');
    }
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

  /// 구독 취소
  static void dispose() {
    _linkSubscription?.cancel();
  }
}
