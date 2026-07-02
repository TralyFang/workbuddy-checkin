#!/bin/bash
# install.sh - 安装 WorkBuddy 签到定时任务
# 自动根据项目所在路径生成 launchd plist 并加载

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_NAME="com.workbuddy.checkin"
PLIST_DEST="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

echo "📦 WorkBuddy 签到定时任务安装器"
echo "项目路径: $PROJECT_DIR"
echo ""

# 确保目录存在
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/screenshots"

# 如果已安装，先卸载
if launchctl list | grep -q "$PLIST_NAME" 2>/dev/null; then
    echo "⏹  卸载旧的定时任务..."
    launchctl unload "$PLIST_DEST" 2>/dev/null
fi

# 生成 plist 文件
cat > "$PLIST_DEST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${PROJECT_DIR}/scripts/checkin_mac.sh</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>7</integer>
        <key>Minute</key>
        <integer>40</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>${PROJECT_DIR}/logs/checkin.log</string>

    <key>StandardErrorPath</key>
    <string>${PROJECT_DIR}/logs/checkin_error.log</string>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLIST

# 加载定时任务
launchctl load "$PLIST_DEST"

echo ""
echo "✅ 定时任务已安装！"
echo "   每天 7:40 触发，加上随机延迟 0~60 分钟"
echo "   实际签到时间: 8:10 ± 30 分钟"
echo ""
echo "📋 常用命令:"
echo "   查看状态: launchctl list | grep workbuddy"
echo "   查看日志: cat $PROJECT_DIR/logs/checkin.log"
echo "   手动测试: SKIP_RANDOM_DELAY=1 $PROJECT_DIR/scripts/checkin_mac.sh"
echo "   卸载任务: $PROJECT_DIR/uninstall.sh"
