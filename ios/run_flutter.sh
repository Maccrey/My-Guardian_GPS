#!/bin/bash

# Flutter 앱 실행을 위한 원스톱 스크립트
# iOS 빌드 중 발생하는 gRPC 모듈맵 문제를 자동으로 해결합니다.

echo "===== Flutter iOS 앱 빌드 및 실행 도우미 ====="

# 현재 디렉토리 확인
if [[ "$(basename $(pwd))" != "ios" ]]; then
  echo "⚠️  이 스크립트는 iOS 디렉토리에서 실행해야 합니다."
  exit 1
fi

# 기기 선택
if [ -z "$1" ]; then
  # 사용 가능한 iOS 시뮬레이터 목록 출력
  echo "📱 사용 가능한 iOS 시뮬레이터:"
  xcrun simctl list devices available | grep -E "iPhone|iPad" | grep -v "unavailable" | sed 's/^[ \t]*/    /'
  echo ""
  echo "💡 사용법: $0 '기기 이름'"
  echo "예: $0 'iPhone 16'"
  echo ""
  read -p "기기 이름을 입력하세요 (Enter=iPhone 16): " DEVICE_NAME
  if [ -z "$DEVICE_NAME" ]; then
    DEVICE_NAME="iPhone 16"
  fi
else
  DEVICE_NAME="$1"
fi

echo "🔧 선택된 기기: $DEVICE_NAME"

# Xcode 프로세스 확인 및 종료
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

# 시뮬레이터 초기화
echo "🔄 iOS 시뮬레이터 초기화 중..."
xcrun simctl shutdown all 2>/dev/null
echo "✅ 모든 시뮬레이터가 종료되었습니다."

# 빌드 환경 문제 확인
echo "🔍 빌드 환경 검사 중..."

# Xcode 빌드 데이터베이스 검사
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"
RUNNER_DIR=$(find "$DERIVED_DATA_DIR" -name "Runner-*" -type d 2>/dev/null)
BUILD_DB_LOCKED=false

if [ -n "$RUNNER_DIR" ]; then
  BUILD_DB=$(find "$RUNNER_DIR" -name "build.db" -type f 2>/dev/null)
  if [ -n "$BUILD_DB" ]; then
    # 파일 잠금 상태 확인
    if lsof "$BUILD_DB" >/dev/null 2>&1; then
      echo "⚠️ 빌드 데이터베이스가 잠겨 있습니다."
      BUILD_DB_LOCKED=true
    fi
  fi
fi

# 잠금 상태이면 정리 스크립트 실행 여부 확인
if [ "$BUILD_DB_LOCKED" = true ]; then
  echo "⚠️ Xcode 빌드 데이터베이스가 잠겨 있어 빌드 실패가 예상됩니다."
  read -p "빌드 환경을 정리하시겠습니까? (y/n, 기본값: y): " CLEAN_BUILD
  CLEAN_BUILD=${CLEAN_BUILD:-y}
  
  if [ "$CLEAN_BUILD" = "y" ] || [ "$CLEAN_BUILD" = "Y" ]; then
    if [ -f "./clean_xcode.sh" ]; then
      echo "🧹 빌드 환경 정리 중..."
      ./clean_xcode.sh
    else
      echo "⚠️ clean_xcode.sh 스크립트를 찾을 수 없습니다. 수동으로 정리가 필요할 수 있습니다."
    fi
  fi
fi

# 모듈맵 파일 확인
echo "🔍 gRPC 모듈맵 파일 확인 중..."
GRPC_MODULEMAP="Pods/Headers/Private/grpc/gRPC-Core.modulemap"
if [ ! -f "$GRPC_MODULEMAP" ]; then
  echo "⚠️ gRPC 모듈맵 파일($GRPC_MODULEMAP)이 없습니다. 생성합니다."
  # pod install 실행
  echo "🔄 Pod 설치 중..."
  pod install
fi

# gRPC 모듈맵 문제 해결
echo "🔄 gRPC 모듈맵 수정 스크립트 실행 중..."
if [ -f "./fix_grpc_permanent.sh" ]; then
  ./fix_grpc_permanent.sh
else
  echo "⚠️ fix_grpc_permanent.sh 스크립트를 찾을 수 없습니다. 대신 fix_grpc_modules.sh를 사용합니다."
  if [ -f "./fix_grpc_modules.sh" ]; then
    ./fix_grpc_modules.sh
  else
    echo "⚠️ 모듈맵 스크립트를 찾을 수 없습니다. 수동으로 문제를 해결해야 할 수 있습니다."
  fi
fi

# 파일 보호 해제 (빌드 문제 발생 시)
GRPC_MODULEMAP_PROTECTED=false
if [ -f "$GRPC_MODULEMAP" ]; then
  # 파일 권한 확인
  FILE_PERMS=$(stat -f "%A" "$GRPC_MODULEMAP" 2>/dev/null)
  if [[ "$FILE_PERMS" == "444" || "$FILE_PERMS" == "555" ]]; then
    GRPC_MODULEMAP_PROTECTED=true
  fi
  
  # chflags 상태 확인
  if command -v chflags &> /dev/null; then
    FLAGS=$(ls -lO "$GRPC_MODULEMAP" | awk '{print $5}')
    if [[ "$FLAGS" == *"uchg"* ]]; then
      GRPC_MODULEMAP_PROTECTED=true
    fi
  fi
fi

# 빌드 전에 모듈맵 파일 백업 생성
echo "💾 모듈맵 파일 백업 생성 중..."
BACKUP_DIR="Pods/ModuleMapBackup"
mkdir -p "$BACKUP_DIR"
if [ -f "$GRPC_MODULEMAP" ]; then
  cp "$GRPC_MODULEMAP" "$BACKUP_DIR/grpc-gRPC-Core.modulemap.bak" 2>/dev/null
  echo "✅ 모듈맵 파일 백업 완료: $BACKUP_DIR/grpc-gRPC-Core.modulemap.bak"
fi

# 모듈맵 파일 보호 상태 확인
if [ "$GRPC_MODULEMAP_PROTECTED" = true ]; then
  echo "🔒 모듈맵 파일이 보호되어 있습니다. 빌드 문제 시 보호를 해제하세요:"
  echo "   chmod +w $GRPC_MODULEMAP"
  echo "   chflags nouchg $GRPC_MODULEMAP"
fi

# 앱 빌드 및 실행
echo "🚀 Flutter 앱 빌드 및 실행 중..."
cd ..

# xcrun으로 시뮬레이터 시작 (기기 확인 후)
echo "📱 시뮬레이터 시작 중..."
xcrun simctl list devices | grep "$DEVICE_NAME" > /dev/null
if [ $? -eq 0 ]; then
  DEVICE_ID=$(xcrun simctl list devices | grep "$DEVICE_NAME" | head -1 | sed -E 's/.*\(([A-Z0-9-]+)\).*/\1/')
  if [ -n "$DEVICE_ID" ]; then
    echo "✅ 시뮬레이터 발견: $DEVICE_NAME ($DEVICE_ID)"
    xcrun simctl boot "$DEVICE_ID" 2>/dev/null
    sleep 2
  else
    echo "⚠️ 기기 ID를 가져올 수 없습니다."
  fi
else
  echo "⚠️ 지정된 기기($DEVICE_NAME)를 찾을 수 없습니다."
  echo "📋 사용 가능한 기기 목록:"
  xcrun simctl list devices | grep -E "iPhone|iPad" | grep -v "unavailable"
fi

flutter run -d "$DEVICE_NAME"
BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
  echo "✅ 앱이 성공적으로 실행되었습니다!"
else
  echo "❌ 앱 빌드 또는 실행에 실패했습니다. (오류 코드: $BUILD_RESULT)"
  
  # 모듈맵 관련 문제 해결 시도
  if [ -f "$BACKUP_DIR/grpc-gRPC-Core.modulemap.bak" ]; then
    echo "🔄 백업에서 모듈맵 파일 복원 시도 중..."
    
    # 보호 해제
    if [ "$GRPC_MODULEMAP_PROTECTED" = true ]; then
      echo "🔓 모듈맵 파일 보호 해제 중..."
      chmod +w "$GRPC_MODULEMAP" 2>/dev/null
      if command -v chflags &> /dev/null; then
        chflags nouchg "$GRPC_MODULEMAP" 2>/dev/null
      fi
    fi
    
    # 백업에서 복원
    cp "$BACKUP_DIR/grpc-gRPC-Core.modulemap.bak" "$GRPC_MODULEMAP" 2>/dev/null
    echo "✅ 모듈맵 파일 복원 완료"
    
    echo "🔄 다시 시도하려면 아래 명령어를 실행하세요:"
    echo "    cd ios && ./run_flutter.sh"
  else
    echo "💡 다음 명령어로 빌드 환경을 정리한 후 다시 시도하세요:"
    echo "    cd ios && ./clean_xcode.sh"
  fi
fi