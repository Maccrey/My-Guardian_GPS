import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 환경 변수에서 API 키를 가져오도록 변경
    // 주의: .env 파일은 빌드 시 Flutter 측에서 처리됨
    // 런타임에 메시지 채널을 통해 키를 가져오도록 수정 필요
    let controller = self.window?.rootViewController as! FlutterViewController
    let mapChannel = FlutterMethodChannel(name: "com.gps_search.maps/api_key", 
                                         binaryMessenger: controller.binaryMessenger)
    
    // Flutter에서 API 키를 가져오는 메서드 (기본값 제공)
    mapChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      // Get Google Maps API Key 메서드 호출 시
      if call.method == "getGoogleMapsApiKey" {
        if let envKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"] {
          result(envKey)
        } else {
          // 환경 변수가 없을 경우 빈 문자열 반환 (Flutter에서 처리)
          result("")
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    // 일단 기본 API 키로 초기화 (실제 배포에서는 보안을 위해 변경 필요)
    // 하지만 Flutter에서 환경 변수 처리 후 다시 설정 가능
    GMSServices.provideAPIKey("") // 빈 문자열 또는 더미 키
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
