#!/bin/bash

echo "Creating gRPC-Core.modulemap..."
mkdir -p "$(pwd)/Pods/Headers/Private/grpc"
cat > "$(pwd)/Pods/Headers/Private/grpc/gRPC-Core.modulemap" << 'EOL'
module gRPC_Core {
  umbrella header "grpc.h"
  export *
  module * { export * }
}
EOL

# Create symbolic link for grpc.h if it doesn't exist
if [ ! -f "$(pwd)/Pods/Headers/Private/grpc/grpc.h" ]; then
  echo "Creating symbolic link for grpc.h..."
  ln -sf "$(pwd)/Pods/gRPC-Core/include/grpc.h" "$(pwd)/Pods/Headers/Private/grpc/grpc.h"
fi

# 파일 권한 설정
chmod 644 "$(pwd)/Pods/Headers/Private/grpc/gRPC-Core.modulemap"
chmod -R 755 "$(pwd)/Pods/Headers/Private/grpc"

echo "✅ gRPC-Core.modulemap fix completed!" 