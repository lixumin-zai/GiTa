#!/bin/bash

# ==============================================================================
# GiTa 双设备一键同步部署脚本
# ==============================================================================
# 功能：一键编译最新代码，并同时安装、运行到已连接的 iPhone 和 iPad 上。
# ==============================================================================

set -e

# 定义设备 ID（自动从 xcrun devicectl 动态获取已连接的 iOS 物理设备）
echo "🔍 正在检测已连接的 iOS 设备..."

# 获取 iPad 和 iPhone 的 UDID
IPAD_UDID=$(xcrun devicectl list devices | grep "iPad" | grep "connected" | awk '{print $3}' | head -n 1)
IPHONE_UDID=$(xcrun devicectl list devices | grep "iPhone" | grep "connected" | awk '{print $3}' | head -n 1)

if [ -z "$IPAD_UDID" ] && [ -z "$IPHONE_UDID" ]; then
    echo "❌ 未检测到任何已连接的 iOS 设备，请确保设备已连接 Mac 并处于解锁状态。"
    exit 1
fi

echo "📱 检测到以下设备："
[ -n "$IPHONE_UDID" ] && echo "  - iPhone UDID: $IPHONE_UDID"
[ -n "$IPAD_UDID" ] && echo "  - iPad UDID: $IPAD_UDID"

# 1. 编译 App (使用工程配置的默认证书签名)
echo "🏗️  正在编译最新的 GiTa 代码 (Debug-iphoneos)..."
xcodebuild -project GiTa.xcodeproj \
           -scheme GiTa \
           -destination 'generic/platform=iOS' \
           -configuration Debug \
           -derivedDataPath build/DerivedData \
           build | grep -E "error:|warning:|BUILD" || true

APP_PATH="build/DerivedData/Build/Products/Debug-iphoneos/GiTa.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ 编译失败，未生成 App 安装包。"
    exit 1
fi

echo "✅ 编译成功！安装包路径: $APP_PATH"

BUNDLE_ID="lismin.gita"

# 2. 并行安装和启动
deploy_to_device() {
    local device_name=$1
    local device_udid=$2
    
    echo "🚀 [$device_name] 开始安装 App..."
    xcrun devicectl device install app --device "$device_udid" "$APP_PATH"
    echo "✅ [$device_name] 安装完成！"
    
    echo "🏃 [$device_name] 正在启动 App..."
    xcrun devicectl device process launch --device "$device_udid" "$BUNDLE_ID"
    echo "🎉 [$device_name] 启动成功！"
}

# 导出函数供 xargs 或后台运行使用
export -f deploy_to_device
export APP_PATH
export BUNDLE_ID

# 在后台并发执行安装以节省时间
PIDS=()

if [ -n "$IPHONE_UDID" ]; then
    deploy_to_device "iPhone" "$IPHONE_UDID" &
    PIDS+=($!)
fi

if [ -n "$IPAD_UDID" ]; then
    deploy_to_device "iPad" "$IPAD_UDID" &
    PIDS+=($!)
fi

# 等待所有安装进程完成
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

echo "🎸 ======================================================= 🎸"
echo "🎉 部署完成！iPhone 和 iPad 均已更新并自动运行最新代码！"
echo "🎸 ======================================================= 🎸"
