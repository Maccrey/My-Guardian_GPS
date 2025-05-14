# Uncomment this line to define a global platform for your project
platform :ios, '14.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

use_modular_headers!

target 'Runner' do
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  pod 'GoogleMaps'
  
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    
    # Firebase 프레임워크 링크 문제 해결
    target.build_configurations.each do |config|
      # 모든 타겟에 Firebase 프레임워크 검색 경로 추가
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] ||= ['$(inherited)']
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '${PODS_ROOT}/FirebaseFirestore/Frameworks'
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '${PODS_ROOT}/FirebaseFirestoreInternal/Frameworks'
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '${PODS_XCFRAMEWORKS_BUILD_DIR}/FirebaseFirestore'
      config.build_settings['FRAMEWORK_SEARCH_PATHS'] << '${PODS_XCFRAMEWORKS_BUILD_DIR}/FirebaseFirestoreInternal'
      
      # 다른 Firebase 관련 설정
      if target.name == 'gRPC-Core'
        config.build_settings['DEFINES_MODULE'] = 'YES'
        config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
      end
    end
  end
  
  installer.pods_project.build_configurations.each do |config|
    config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
  end
  
  installer.pods_project.targets.each do |target|
    if target.name == 'BoringSSL-GRPC'
      target.source_build_phase.files.each do |file|
        if file.settings && file.settings['COMPILER_FLAGS']
          flags = file.settings['COMPILER_FLAGS'].split
          flags.reject! { |flag| flag == '-GCC_WARN_INHIBIT_ALL_WARNINGS' }
          file.settings['COMPILER_FLAGS'] = flags.join(' ')
        end
      end
    end
  end
  
  # gRPC-Core.modulemap 생성
  grpc_private_headers = File.join(__dir__, 'Pods', 'Headers', 'Private', 'grpc')
  grpc_modulemap = File.join(grpc_private_headers, 'gRPC-Core.modulemap')
  unless File.exist?(grpc_modulemap)
    FileUtils.mkdir_p(grpc_private_headers)
    File.open(grpc_modulemap, 'w') do |f|
      f.puts <<~MAP
        module gRPC_Core {
          umbrella header "grpc.h"
          export *
          module * { export * }
        }
      MAP
    end
    puts "✅ gRPC-Core.modulemap 수동 생성 완료"
  end
end 