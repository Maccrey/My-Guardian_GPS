#!/bin/sh

# 프로젝트 루트 디렉토리
PROJECT_ROOT="${SRCROOT}/.."
ENV_FILE="${PROJECT_ROOT}/.env"

# .env 파일 읽기
if [ -f "$ENV_FILE" ]; then
  # GOOGLE_MAPS_API_KEY 추출 및 환경 변수로 설정
  export GOOGLE_MAPS_API_KEY=$(grep '^GOOGLE_MAPS_API_KEY=' "$ENV_FILE" | cut -d '=' -f 2)
  echo "GOOGLE_MAPS_API_KEY: $GOOGLE_MAPS_API_KEY"
else
  echo "Warning: .env file not found at $ENV_FILE"
fi 