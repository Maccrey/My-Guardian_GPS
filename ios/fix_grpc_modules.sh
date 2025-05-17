#!/bin/bash

echo "===== gRPC-Core 및 BoringSSL-GRPC ModuleMap 파일 생성 도구 ====="
echo "Creating gRPC-Core and BoringSSL-GRPC modulemap files..."

# 필요한 디렉토리 생성
mkdir -p "Pods/Headers/Private/gRPC-Core"
mkdir -p "Pods/Headers/Private/grpc"
mkdir -p "Pods/Headers/Private/BoringSSL-GRPC"
mkdir -p "Pods/Headers/Public/gRPC-Core"
mkdir -p "Pods/Headers/Public/BoringSSL-GRPC"

# 디렉토리 권한 설정
chmod 755 "Pods/Headers/Private/gRPC-Core"
chmod 755 "Pods/Headers/Private/grpc"
chmod 755 "Pods/Headers/Private/BoringSSL-GRPC"
chmod 755 "Pods/Headers/Public/gRPC-Core"
chmod 755 "Pods/Headers/Public/BoringSSL-GRPC"

# gRPC-Core 모듈맵 파일 생성 (기존 방식)
cat > "Pods/Headers/Private/gRPC-Core/module.modulemap" << EOF
framework module gRPC_Core {
  umbrella header "gRPC-Core-umbrella.h"
  export *
  module * { export * }
}
EOF

# grpc 디렉토리에도 동일한 파일 생성 (오류에서 언급된 경로)
cat > "Pods/Headers/Private/grpc/gRPC-Core.modulemap" << EOF
framework module gRPC_Core {
  umbrella header "gRPC-Core-umbrella.h"
  export *
  module * { export * }
}
EOF

# Public 경로에도 생성
cat > "Pods/Headers/Public/gRPC-Core/module.modulemap" << EOF
framework module gRPC_Core {
  umbrella header "gRPC-Core-umbrella.h"
  export *
  module * { export * }
}
EOF

# BoringSSL-GRPC 모듈맵 파일 생성
cat > "Pods/Headers/Private/BoringSSL-GRPC/module.modulemap" << EOF
framework module BoringSSL_GRPC {
  umbrella header "BoringSSL-GRPC-umbrella.h"
  export *
  module * { export * }
}
EOF

cat > "Pods/Headers/Public/BoringSSL-GRPC/module.modulemap" << EOF
framework module BoringSSL_GRPC {
  umbrella header "BoringSSL-GRPC-umbrella.h"
  export *
  module * { export * }
}
EOF

# 파일 권한 설정 (읽기 전용)
chmod 444 "Pods/Headers/Private/gRPC-Core/module.modulemap"
chmod 444 "Pods/Headers/Private/grpc/gRPC-Core.modulemap"
chmod 444 "Pods/Headers/Public/gRPC-Core/module.modulemap"
chmod 444 "Pods/Headers/Private/BoringSSL-GRPC/module.modulemap"
chmod 444 "Pods/Headers/Public/BoringSSL-GRPC/module.modulemap"

# 파일 보호 (macOS 전용)
if command -v chflags &> /dev/null; then
  echo "🔒 모듈맵 파일 보호 설정 중..."
  chflags uchg "Pods/Headers/Private/gRPC-Core/module.modulemap" 2>/dev/null
  chflags uchg "Pods/Headers/Private/grpc/gRPC-Core.modulemap" 2>/dev/null
  chflags uchg "Pods/Headers/Public/gRPC-Core/module.modulemap" 2>/dev/null
  chflags uchg "Pods/Headers/Private/BoringSSL-GRPC/module.modulemap" 2>/dev/null
  chflags uchg "Pods/Headers/Public/BoringSSL-GRPC/module.modulemap" 2>/dev/null
fi

# 백업 생성
BACKUP_DIR="Pods/ModuleMapBackup"
mkdir -p "$BACKUP_DIR"
cp "Pods/Headers/Private/gRPC-Core/module.modulemap" "$BACKUP_DIR/gRPC-Core-module.modulemap" 2>/dev/null
cp "Pods/Headers/Private/grpc/gRPC-Core.modulemap" "$BACKUP_DIR/grpc-gRPC-Core.modulemap" 2>/dev/null
cp "Pods/Headers/Private/BoringSSL-GRPC/module.modulemap" "$BACKUP_DIR/BoringSSL-GRPC-module.modulemap" 2>/dev/null

echo "✅ Done creating modulemap files!"
echo "📋 생성된 파일:"
ls -la "Pods/Headers/Private/grpc"
ls -la "Pods/Headers/Private/gRPC-Core"

echo "💡 팁: 빌드 실패 시 chmod +w 명령어로 파일 권한을 변경하고 다시 시도하세요." 