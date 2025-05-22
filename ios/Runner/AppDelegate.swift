import Flutter
import UIKit
import GoogleMaps
import flutter_background_service_ios

@main
@objc class AppDelegate: FlutterAppDelegate {
  // API 키 저장용 변수
  private var googleMapsApiKey: String? = nil
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 백그라운드 서비스 등록
    SwiftFlutterBackgroundServicePlugin.registerForBackgroundService(application)
    
    let controller = self.window?.rootViewController as! FlutterViewController
    let mapChannel = FlutterMethodChannel(name: "com.gps_search.maps/api_key", 
                                         binaryMessenger: controller.binaryMessenger)
    
    // Flutter에서 API 키를 설정하는 메서드
    mapChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      
      if call.method == "setGoogleMapsApiKey" {
        if let apiKey = call.arguments as? String, !apiKey.isEmpty {
          self.googleMapsApiKey = apiKey
          GMSServices.provideAPIKey(apiKey)
          debugPrint("✅ Google Maps API Key 설정 완료 (Swift)")
          result(true)
        } else {
          debugPrint("❌ 유효하지 않은 Google Maps API Key 수신 (Swift)")
          result(FlutterError(code: "INVALID_API_KEY",
                               message: "API key is null or empty",
                               details: nil))
        }
      } else if call.method == "getGoogleMapsApiKey" {
        // 저장된 API 키 반환
        result(self.googleMapsApiKey)
        debugPrint("📤 Google Maps API Key 반환 (Swift)")
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
