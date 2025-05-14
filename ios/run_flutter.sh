#!/bin/bash

# 현재 디렉토리가 ios 폴더인지 확인
if [[ $(basename "$PWD") != "ios" ]]; then
  echo "⚠️ 이 스크립트는 ios 폴더에서 실행해야 합니다."
  echo "cd ios 명령어로 이동 후 실행하세요."
  exit 1
fi

# gRPC-Core.modulemap 수정
echo "🔧 gRPC-Core.modulemap 생성 중..."
./fix_grpc.sh

# 상위 디렉토리로 이동
cd ..

# flutter run 실행 (pod install 건너뛰기)
echo "🚀 Flutter 앱 실행 중..."
flutter run --no-pub

echo "✅ 완료!" 