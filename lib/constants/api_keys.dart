import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// API 키 상수 모음
class ApiKeys {
  /// Google Maps API 키 - .env 파일에서 로드
  /// 사용 전에 반드시 dotenv.load()가 호출되어야 함
  static String get googleMapsApiKey {
    try {
      // .env 파일에서 API 키 로드 시도
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

      if (apiKey == null || apiKey.isEmpty) {
        // 개발용 경고 메시지 (실제 배포 시에는 제거하거나 다른 방식으로 처리)
        debugPrint('⚠️ 경고: .env 파일에서 GOOGLE_MAPS_API_KEY를 찾을 수 없습니다.');

        // 개발 환경에서 기본값 제공
        if (kDebugMode) {
          return 'YOUR_DUMMY_API_KEY';
        }

        return '';
      }

      return apiKey;
    } catch (e) {
      debugPrint('❌ API 키 로드 중 오류 발생: $e');

      // 개발 환경에서 기본값 제공
      if (kDebugMode) {
        return 'YOUR_DUMMY_API_KEY';
      }

      return '';
    }
  }
}
