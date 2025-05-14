#!/bin/bash

# 이 스크립트는 gRPC-Core.modulemap 문제를 영구적으로 해결합니다.
# 이 스크립트는 pod install 후에 실행해야 합니다.

echo "Creating permanent fix for gRPC-Core.modulemap..."

# 1. 필요한 디렉토리 생성
mkdir -p "$(pwd)/Pods/Headers/Private/grpc"

# 2. gRPC-Core.modulemap 파일 생성
cat > "$(pwd)/Pods/Headers/Private/grpc/gRPC-Core.modulemap" << 'EOL'
module gRPC_Core {
  umbrella header "grpc.h"
  export *
  module * { export * }
}
EOL

# 3. grpc.h 심볼릭 링크 생성
ln -sf "$(pwd)/Pods/gRPC-Core/include/grpc.h" "$(pwd)/Pods/Headers/Private/grpc/grpc.h"

# 4. 파일 권한 설정
chmod 644 "$(pwd)/Pods/Headers/Private/grpc/gRPC-Core.modulemap"

# 5. 디렉토리 권한 설정
chmod -R 755 "$(pwd)/Pods/Headers/Private/grpc"

# 6. Podfile 수정하여 post_install 후크 추가
if ! grep -q "# GRPC-Core modulemap fix" "$(pwd)/Podfile"; then
  echo "Adding post_install hook to Podfile..."
  cat >> "$(pwd)/Podfile" << 'EOL'

# GRPC-Core modulemap fix
post_install do |installer|
  # 기존 post_install 블록이 있다면 여기에 추가
  system("cd $PODS_ROOT/.. && ./fix_grpc.sh")
end
EOL
fi

echo "✅ Permanent gRPC-Core.modulemap fix completed!"
echo "이제 pod install 후에도 modulemap이 자동으로 생성됩니다." 