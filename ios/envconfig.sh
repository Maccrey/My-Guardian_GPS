#!/bin/sh

# 프로젝트 루트 디렉토리 찾기
PROJECT_ROOT="$(dirname "$0")/.."
ENV_FILE="$PROJECT_ROOT/.env"

# .env 파일 읽기
if [ -f "$ENV_FILE" ]; then
  echo "Reading from .env file: $ENV_FILE"
  
  # GOOGLE_MAPS_API_KEY 추출
  GOOGLE_MAPS_API_KEY=$(grep '^GOOGLE_MAPS_API_KEY=' "$ENV_FILE" | cut -d '=' -f 2)
  
  # Debug 및 Release xcconfig 파일 업데이트
  for CONFIG_TYPE in "Debug" "Release"; do
    XCCONFIG_FILE="$PROJECT_ROOT/ios/Flutter/$CONFIG_TYPE.xcconfig"
    
    # 기존 파일이 없으면 생성
    if [ ! -f "$XCCONFIG_FILE" ]; then
      echo "Creating $XCCONFIG_FILE"
      touch "$XCCONFIG_FILE"
    fi
    
    # API 키 설정 추가 또는 업데이트
    if grep -q "GOOGLE_MAPS_API_KEY" "$XCCONFIG_FILE"; then
      # 기존 API 키 라인 업데이트
      sed -i '' "s/GOOGLE_MAPS_API_KEY=.*/GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY/" "$XCCONFIG_FILE"
    else
      # 새로운 API 키 라인 추가
      echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" >> "$XCCONFIG_FILE"
    fi
    
    echo "Updated GOOGLE_MAPS_API_KEY in $XCCONFIG_FILE"
  done
else
  echo "Error: .env file not found at $ENV_FILE"
  exit 1
fi 