package com.maccrey.watch_over

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import androidx.annotation.NonNull
import io.flutter.plugin.common.MethodChannel
import android.content.Context

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.gps_search.maps/api_key"
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // API 키를 위한 메소드 채널 설정
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getGoogleMapsApiKey" -> {
                    // 리소스에서 API 키 가져오기
                    val apiKey = this.getString(R.string.google_maps_api_key)
                    println("✅ Android에서 Maps API 키 반환: $apiKey")
                    result.success(apiKey)
                }
                "setGoogleMapsApiKey" -> {
                    // 안드로이드에서는 런타임에 API 키를 설정할 필요 없음 (매니페스트에 정의됨)
                    // 하지만 통일성을 위해 메소드는 지원
                    val apiKey = call.arguments as String?
                    println("ℹ️ Android에서 API 키 설정 요청 (무시됨): $apiKey")
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
} 