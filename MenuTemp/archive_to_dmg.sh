#
//  archive_to_dmg.sh
//  MenuTemp
//
//  Created by isbtsuns@icloud.com on 2025/8/3.
//

#!/bin/bash
set -e

# ===== 配置 =====
SCHEME="MenuTemp"         # 你的主应用名称
ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives"  # Xcode 存放 Archive 的目录
DMG_NAME="${SCHEME}.dmg"
OUTPUT_DIR="./build"

# ===== 找到最新的 .xcarchive =====
LATEST_ARCHIVE=$(find "$ARCHIVE_DIR" -name "*.xcarchive" -type d -print0 \
  | xargs -0 ls -td | head -n 1)

if [ -z "$LATEST_ARCHIVE" ]; then
  echo "❌ 没找到任何 .xcarchive，请先在 Xcode 里 Product → Archive"
  exit 1
fi

echo "📦 找到最新 Archive: $LATEST_ARCHIVE"

# ===== 找到 .app =====
APP_PATH="$LATEST_ARCHIVE/Products/Applications/${SCHEME}.app"
if [ ! -d "$APP_PATH" ]; then
  echo "❌ 在 Archive 中找不到 ${SCHEME}.app"
  exit 1
fi

# ===== 准备输出目录 =====
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 复制 .app
cp -R "$APP_PATH" "$OUTPUT_DIR"

# ===== 打包 DMG =====
hdiutil create \
  -volname "$SCHEME" \
  -srcfolder "$OUTPUT_DIR/${SCHEME}.app" \
  -ov -format UDZO "$OUTPUT_DIR/$DMG_NAME"

echo "✅ DMG 已生成: $OUTPUT_DIR/$DMG_NAME"
open "$OUTPUT_DIR"
