#!/bin/bash
# ============================================================
# Nexus 标准构建脚本
# 应用: KeyHub (com.nexus.tool.keyhub)
# 用法:
#   ./build.sh              # 编译 + 同步资源 + 签名
#   ./build.sh --no-sign    # 只编译不同名
#   ./build.sh --clean      # 清理后重新编译
# ============================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="KeyHub"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 解析参数
DO_SIGN=true
DO_CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --no-sign) DO_SIGN=false ;;
        --clean)   DO_CLEAN=true ;;
        *) echo "未知参数: $arg"; exit 1 ;;
    esac
done

# 清理
if [ "$DO_CLEAN" = true ]; then
    echo "🧹 清理旧构建产物..."
    rm -rf "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    rm -rf "$APP_BUNDLE/Contents/Resources/guides"
fi

# 确保目录存在
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "🔨 编译 $APP_NAME..."

# 收集所有 Swift 源文件（Sources/ 下所有 .swift）
SWIFT_FILES=$(find "$PROJECT_DIR/Sources" -name "*.swift" | sort)

# 编译
swiftc $SWIFT_FILES \
    -o "$EXECUTABLE" \
    -framework Cocoa \
    -framework Carbon \
    -O \
    -whole-module-optimization

echo "✅ 编译完成: $EXECUTABLE"

# 同步资源到 app bundle
echo "📦 同步资源到 app bundle..."

# guides/ 数据文件
if [ -d "$PROJECT_DIR/guides" ]; then
    mkdir -p "$APP_BUNDLE/Contents/Resources/guides"
    cp -R "$PROJECT_DIR/guides/"*.md "$APP_BUNDLE/Contents/Resources/guides/" 2>/dev/null || true
fi

# 签名
if [ "$DO_SIGN" = true ]; then
    echo "✍️  签名中..."
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "✅ 签名完成"
fi

echo ""
echo "🎉 构建完成！"
echo "   应用: $APP_BUNDLE"
echo "   运行: open $APP_BUNDLE"
echo "   重启: pkill -9 -f $APP_NAME && open $APP_BUNDLE"
