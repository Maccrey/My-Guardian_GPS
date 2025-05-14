#!/bin/bash

echo "Creating gRPC-Core.modulemap..."
mkdir -p "$(pwd)/Pods/Headers/Private/grpc"

# 모듈 이름 형식 수정 - 따옴표 없이, 하이픈 대신 언더스코어 사용
cat > "$(pwd)/Pods/Headers/Private/grpc/gRPC-Core.modulemap" << 'MODULE_MAP'
module gRPC_Core {
  umbrella header "grpc.h"
  export *
  module * { export * }
}
MODULE_MAP

# Create symbolic link for grpc.h if it doesn't exist
if [ ! -f "$(pwd)/Pods/Headers/Private/grpc/grpc.h" ]; then
  echo "Creating symbolic link for grpc.h..."
  ln -sf "$(pwd)/Pods/gRPC-Core/include/grpc.h" "$(pwd)/Pods/Headers/Private/grpc/grpc.h"
fi

echo "✅ gRPC-Core.modulemap fix completed!" 