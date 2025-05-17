#!/bin/bash

# gRPC 모듈맵 오류를 영구적으로 해결하는 스크립트

echo "===== Flutter iOS gRPC ModuleMap 문제 영구 해결 도구 ====="
echo "이 스크립트는 gRPC 모듈맵 오류를 자동으로 감지하고 수정합니다."
echo "빌드 프로세스가 시작되기 전에 실행하세요."

# 필요한 디렉토리 경로 설정
PODS_DIR="Pods"
HEADERS_DIR="$PODS_DIR/Headers"
PRIVATE_DIR="$HEADERS_DIR/Private"
PUBLIC_DIR="$HEADERS_DIR/Public"

# Pods 디렉토리 존재 여부 확인
if [ ! -d "$PODS_DIR" ]; then
  echo "⚠️ Pods 디렉토리가 존재하지 않습니다. pod install을 먼저 실행하세요."
  exit 1
fi

# 확인할 경로와 파일 배열
DIRS_TO_CHECK=(
  "$PRIVATE_DIR/gRPC-Core"
  "$PRIVATE_DIR/grpc"
  "$PRIVATE_DIR/BoringSSL-GRPC"
  "$PUBLIC_DIR/gRPC-Core"
  "$PUBLIC_DIR/BoringSSL-GRPC"
)

FILES_TO_CHECK=(
  "$PRIVATE_DIR/gRPC-Core/module.modulemap"
  "$PRIVATE_DIR/grpc/gRPC-Core.modulemap"
  "$PRIVATE_DIR/BoringSSL-GRPC/module.modulemap"
  "$PUBLIC_DIR/gRPC-Core/module.modulemap"
  "$PUBLIC_DIR/BoringSSL-GRPC/module.modulemap"
)

# 모듈맵 내용
GRPC_MODULEMAP="framework module gRPC_Core {
  umbrella header \"gRPC-Core-umbrella.h\"
  export *
  module * { export * }
}"

BORING_SSL_MODULEMAP="framework module BoringSSL_GRPC {
  umbrella header \"BoringSSL-GRPC-umbrella.h\"
  export *
  module * { export * }
}"

# 백업 디렉토리
BACKUP_DIR="$PODS_DIR/ModuleMapBackup"

# 함수: 디렉토리 생성 및 권한 부여
create_dir_with_permissions() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    echo "📁 $dir 생성 중..."
    mkdir -p "$dir"
    chmod 755 "$dir"
  fi
}

# 함수: 모듈맵 파일 생성 및 권한 부여
create_modulemap_file() {
  local file="$1"
  local content="$2"
  
  # 기존 파일 삭제 (파일이 있으면)
  if [ -f "$file" ]; then
    rm -f "$file" 2>/dev/null || sudo rm -f "$file" 2>/dev/null
  fi
  
  # 새 파일 생성
  echo "$content" > "$file"
  
  # 파일 권한 설정
  chmod 644 "$file"
  chmod +w "$file"
}

# 디렉토리 확인 및 생성
echo "🔍 필요한 디렉토리 확인 및 생성 중..."
for dir in "${DIRS_TO_CHECK[@]}"; do
  create_dir_with_permissions "$dir"
done

# 백업 디렉토리 생성
create_dir_with_permissions "$BACKUP_DIR"

# 모듈맵 파일 생성
echo "📝 필요한 모듈맵 파일 생성 중..."
create_modulemap_file "$PRIVATE_DIR/gRPC-Core/module.modulemap" "$GRPC_MODULEMAP"
create_modulemap_file "$PRIVATE_DIR/grpc/gRPC-Core.modulemap" "$GRPC_MODULEMAP"
create_modulemap_file "$PRIVATE_DIR/BoringSSL-GRPC/module.modulemap" "$BORING_SSL_MODULEMAP"
create_modulemap_file "$PUBLIC_DIR/gRPC-Core/module.modulemap" "$GRPC_MODULEMAP"
create_modulemap_file "$PUBLIC_DIR/BoringSSL-GRPC/module.modulemap" "$BORING_SSL_MODULEMAP"

# 추가적인 보호: 파일에 쓰기 권한 명시적 부여
echo "🔒 모듈맵 파일 보호 설정 중..."
chmod +w "$PRIVATE_DIR/gRPC-Core/module.modulemap"
chmod +w "$PRIVATE_DIR/grpc/gRPC-Core.modulemap"
chmod +w "$PRIVATE_DIR/BoringSSL-GRPC/module.modulemap"
chmod +w "$PUBLIC_DIR/gRPC-Core/module.modulemap"
chmod +w "$PUBLIC_DIR/BoringSSL-GRPC/module.modulemap"

# 추가적인 보호: 부모 디렉토리에 쓰기 권한 부여
chmod -R 755 "$PRIVATE_DIR/gRPC-Core"
chmod -R 755 "$PRIVATE_DIR/grpc"
chmod -R 755 "$PRIVATE_DIR/BoringSSL-GRPC"
chmod -R 755 "$PUBLIC_DIR/gRPC-Core"
chmod -R 755 "$PUBLIC_DIR/BoringSSL-GRPC"

# 추가: 시스템 보호를 피하기 위해 sudo로 권한 설정
if [ ! -w "$PRIVATE_DIR/grpc/gRPC-Core.modulemap" ]; then
  sudo chmod 644 "$PRIVATE_DIR/grpc/gRPC-Core.modulemap"
  sudo chmod +w "$PRIVATE_DIR/grpc/gRPC-Core.modulemap"
fi

# 모듈맵 백업 생성
echo "💾 모듈맵 파일 백업 생성 중..."
cp -f "$PRIVATE_DIR/gRPC-Core/module.modulemap" "$BACKUP_DIR/private_gRPC-Core_module.modulemap" 2>/dev/null || true
cp -f "$PRIVATE_DIR/grpc/gRPC-Core.modulemap" "$BACKUP_DIR/private_grpc_gRPC-Core.modulemap" 2>/dev/null || true
cp -f "$PRIVATE_DIR/BoringSSL-GRPC/module.modulemap" "$BACKUP_DIR/private_BoringSSL-GRPC_module.modulemap" 2>/dev/null || true
cp -f "$PUBLIC_DIR/gRPC-Core/module.modulemap" "$BACKUP_DIR/public_gRPC-Core_module.modulemap" 2>/dev/null || true
cp -f "$PUBLIC_DIR/BoringSSL-GRPC/module.modulemap" "$BACKUP_DIR/public_BoringSSL-GRPC_module.modulemap" 2>/dev/null || true

# 결과 출력
echo "✅ 모든 모듈맵 파일 생성 완료!"
echo "📋 생성된 파일 확인:"
for file in "${FILES_TO_CHECK[@]}"; do
  if [ -f "$file" ]; then
    echo "  ✓ $file"
  else
    echo "  ✗ $file (생성 실패)"
  fi
done

# 추가 팁 출력
echo "ℹ️ Podfile에 모듈맵 보호 코드를 추가하는 것을 고려하세요."
echo "💡 팁: Podfile의 post_install 섹션에 다음 내용을 추가하세요:"
echo ""
echo "post_install do |installer|"
echo "  # 기존 post_install 코드..."
echo "  # gRPC 모듈맵 문제 해결"
echo "  system('bash ./fix_grpc_permanent.sh')"
echo "end"
echo "🚀 이제 flutter run 명령어를 사용하여 앱을 실행해 보세요."
echo "💡 팁: 새로운 빌드를 할 때마다 이 스크립트를 실행하세요."
echo "💡 빌드 실패 시 chmod +w 명령어로 파일 권한을 변경하고 다시 시도하세요." 