import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import '../constants/api_keys.dart';

/// 맵 API 관련 서비스
/// 플랫폼별 API 키 로드를 안전하게 처리
class MapApiService {
  static const _methodChannel = MethodChannel('com.gps_search.maps/api_key');
  static String? _apiKey;

  /// Google Maps API 키를 안전하게 가져옴
  /// .env 파일, 플랫폼별 저장소 등 다양한 소스에서 키를 가져옴
  static Future<String> getGoogleMapsApiKey() async {
    // 이미 로드된 키가 있으면 반환
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      return _apiKey!;
    }

    try {
      // 1. 먼저 환경 변수에서 키 가져오기 시도 (.env 파일)
      _apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

      // 2. 플랫폼별 네이티브 코드에서 키 가져오기 시도
      if (_apiKey == null || _apiKey!.isEmpty) {
        if (Platform.isIOS) {
          try {
            final String? iosApiKey =
                await _methodChannel.invokeMethod('getGoogleMapsApiKey');
            if (iosApiKey != null && iosApiKey.isNotEmpty) {
              _apiKey = iosApiKey;
              debugPrint('✅ iOS 네이티브 코드에서 Google Maps API 키 로드 성공');
            }
          } catch (e) {
            debugPrint('⚠️ iOS 네이티브 코드에서 API 키 로드 실패: $e');
          }
        } else if (Platform.isAndroid) {
          try {
            final String? androidApiKey =
                await _methodChannel.invokeMethod('getGoogleMapsApiKey');
            if (androidApiKey != null && androidApiKey.isNotEmpty) {
              _apiKey = androidApiKey;
              debugPrint('✅ Android 네이티브 코드에서 Google Maps API 키 로드 성공');
            }
          } catch (e) {
            debugPrint('⚠️ Android 네이티브 코드에서 API 키 로드 실패: $e');
          }
        }
      }

      // 3. 상수 클래스에서 가져오기 (이전에는 직접 하드코딩됨)
      if (_apiKey == null || _apiKey!.isEmpty) {
        _apiKey = ApiKeys.googleMapsApiKey;
        debugPrint('ℹ️ 상수에서 Google Maps API 키 로드');
      }

      // 4. 최종 확인
      if (_apiKey == null || _apiKey!.isEmpty) {
        debugPrint('⚠️ 경고: Google Maps API 키를 찾을 수 없습니다.');
        // 빈 키 대신 임시 값 반환 (실제 앱에서는 적절히 처리 필요)
        return '';
      }

      return _apiKey!;
    } catch (e) {
      debugPrint('⚠️ Google Maps API 키 로드 중 오류: $e');
      return '';
    }
  }

  /// iOS에 Google Maps API 키를 설정하는 메소드
  /// Flutter에서 로드한 API 키를 Swift 코드로 전달
  static Future<bool> setGoogleMapsApiKeyForIOS() async {
    // iOS 플랫폼인 경우에만 실행
    if (!Platform.isIOS) {
      debugPrint('📱 iOS 플랫폼이 아니므로 API 키 설정 건너뜀');
      return true;
    }

    try {
      // API 키 로드
      final apiKey = await getGoogleMapsApiKey();

      if (apiKey.isEmpty) {
        debugPrint('❌ API 키가 비어있어 iOS에 설정할 수 없음');
        return false;
      }

      // Swift 코드로 API 키 전달
      final result =
          await _methodChannel.invokeMethod('setGoogleMapsApiKey', apiKey);
      debugPrint('✅ iOS에 Google Maps API 키 설정 성공: $result');
      return true;
    } catch (e) {
      debugPrint('❌ iOS에 Google Maps API 키 설정 실패: $e');
      return false;
    }
  }

  /// Android에 Google Maps API 키를 설정하는 메소드
  /// 안드로이드에서는 실제로 런타임에 설정할 필요는 없지만
  /// 일관성을 위해 API 제공 (build.gradle에서 이미 설정됨)
  static Future<bool> setGoogleMapsApiKeyForAndroid() async {
    // Android 플랫폼인 경우에만 실행
    if (!Platform.isAndroid) {
      debugPrint('📱 Android 플랫폼이 아니므로 API 키 설정 건너뜀');
      return true;
    }

    try {
      // API 키 로드
      final apiKey = await getGoogleMapsApiKey();

      if (apiKey.isEmpty) {
        debugPrint('❌ API 키가 비어있어 Android에 설정할 수 없음');
        return false;
      }

      // Android 코드로 API 키 전달 (실제로는 영향 없음)
      final result =
          await _methodChannel.invokeMethod('setGoogleMapsApiKey', apiKey);
      debugPrint('✅ Android에 Google Maps API 키 설정 성공: $result');
      return true;
    } catch (e) {
      debugPrint('❌ Android에 Google Maps API 키 설정 실패: $e');
      return false;
    }
  }

  /// 플랫폼에 맞게 Google Maps API 키 설정
  /// iOS 또는 Android 플랫폼에 따라 적절한 메소드 호출
  static Future<bool> setGoogleMapsApiKeyForPlatform() async {
    if (Platform.isIOS) {
      return setGoogleMapsApiKeyForIOS();
    } else if (Platform.isAndroid) {
      return setGoogleMapsApiKeyForAndroid();
    }
    return false;
  }
}
