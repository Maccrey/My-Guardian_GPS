#!/bin/bash

# 프로젝트 루트에서 ios/run_flutter.sh를 실행하는 래퍼 스크립트

echo "===== Flutter iOS 앱 빌드 및 실행 도우미 ====="

# 현재 디렉토리가 프로젝트 루트인지 확인
if [ ! -d "ios" ]; then
  echo "⚠️  이 스크립트는 Flutter 프로젝트 루트 디렉토리에서 실행해야 합니다."
  exit 1
fi

# iOS 디렉토리로 이동
cd ios

# 실행 권한 확인 및 부여
if [ ! -x "run_flutter.sh" ]; then
  echo "🔧 run_flutter.sh에 실행 권한 부여 중..."
  chmod +x run_flutter.sh
fi

# 파라미터를 그대로 전달하여 실행
./run_flutter.sh "$@" 