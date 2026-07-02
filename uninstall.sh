#!/bin/bash
# uninstall.sh - 卸载 WorkBuddy 签到定时任务

PLIST_NAME="com.workbuddy.checkin"
PLIST_DEST="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

echo "🗑  卸载 WorkBuddy 签到定时任务..."

if [ -f "$PLIST_DEST" ]; then
    launchctl unload "$PLIST_DEST" 2>/dev/null
    rm -f "$PLIST_DEST"
    echo "✅ 定时任务已卸载"
else
    echo "ℹ️  未找到已安装的定时任务"
fi
