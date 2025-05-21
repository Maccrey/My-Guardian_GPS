import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API 키 상수 모음
class ApiKeys {
  /// Google Maps API 키 - .env 파일에서 로드
  /// 사용 전에 반드시 dotenv.load()가 호출되어야 함
  static String get googleMapsApiKey {
    // .env 파일에서 API 키 로드 시도
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      // 개발용 경고 메시지 (실제 배포 시에는 제거하거나 다른 방식으로 처리)
      print('⚠️ 경고: .env 파일에서 GOOGLE_MAPS_API_KEY를 찾을 수 없습니다.');
      return '';
    }

    return apiKey;
  }
}
