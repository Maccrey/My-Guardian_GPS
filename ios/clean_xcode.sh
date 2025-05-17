#!/bin/bash

# Xcode 빌드 데이터베이스 잠금 및 캐시 문제를 해결하는 스크립트

echo "===== Xcode 빌드 문제 해결 도구 ====="
echo "이 스크립트는 Xcode 빌드 데이터베이스 잠금 및 캐시 문제를 해결합니다."

# DerivedData 디렉토리 경로
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
RUNNER_DIR=$(find "$DERIVED_DATA_DIR" -name "Runner-*" -type d 2>/dev/null)

# 실행 중인 Xcode 프로세스 확인 및 종료
echo "🔍 Xcode 관련 프로세스 확인 중..."
XCODE_PROCESSES=$(pgrep -l "Xcode|xcrun|xcodebuild")

if [ -n "$XCODE_PROCESSES" ]; then
  echo "📋 실행 중인 Xcode 관련 프로세스:"
  echo "$XCODE_PROCESSES"
  
  echo "🛑 Xcode 관련 프로세스 종료 중..."
  killall Xcode xcrun xcodebuild 2>/dev/null
  sleep 2
  
  # 강제 종료가 필요한 경우
  REMAINING=$(pgrep -l "Xcode|xcrun|xcodebuild")
  if [ -n "$REMAINING" ]; then
    echo "⚠️ 일부 프로세스가 계속 실행 중입니다. 강제 종료합니다..."
    killall -9 Xcode xcrun xcodebuild 2>/dev/null
  fi
else
  echo "✅ 실행 중인 Xcode 프로세스가 없습니다."
fi

# Runner 디렉토리 찾기 및 정리
if [ -n "$RUNNER_DIR" ]; then
  echo "🔍 Runner 빌드 디렉토리 발견: $RUNNER_DIR"
  
  # 빌드 데이터베이스 파일 확인
  BUILD_DB=$(find "$RUNNER_DIR" -name "build.db" -type f 2>/dev/null)
  if [ -n "$BUILD_DB" ]; then
    echo "🗑️ 빌드 데이터베이스 삭제 중: $BUILD_DB"
    rm -f "$BUILD_DB"
    echo "✅ 빌드 데이터베이스가 삭제되었습니다."
  fi
  
  # 빌드 중간 파일 정리
  echo "🧹 Runner 빌드 중간 파일 정리 중..."
  INTERMEDIATES_DIR=$(find "$RUNNER_DIR" -path "*/Build/Intermediates.noindex" -type d 2>/dev/null)
  if [ -n "$INTERMEDIATES_DIR" ]; then
    echo "🗑️ 중간 빌드 파일 정리 중: $INTERMEDIATES_DIR"
    rm -rf "$INTERMEDIATES_DIR"
    echo "✅ 중간 빌드 파일이 정리되었습니다."
  fi
else
  echo "ℹ️ Runner 빌드 디렉토리를 찾을 수 없습니다."
fi

# 시뮬레이터 초기화
echo "🔄 iOS 시뮬레이터 초기화 중..."
xcrun simctl shutdown all 2>/dev/null
echo "✅ 모든 시뮬레이터가 종료되었습니다."

# Flutter 클린
echo "🧹 Flutter 프로젝트 정리 중..."
cd ..
flutter clean

# 다시 iOS 디렉토리로 이동
cd ios

# Pods 정리 및 재설치
echo "🔄 Pods 정리 및 재설치 중..."
rm -rf Pods Podfile.lock
pod install

echo "✅ 모든 정리 작업이 완료되었습니다. 이제 앱을 다시 빌드해 보세요."
echo "💡 팁: 다음 명령어로 앱을 실행하세요: ./run_flutter.sh" 