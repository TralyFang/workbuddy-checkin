#!/bin/bash
# uninstall.sh - 卸载 WorkBuddy 签到定时任务并清理所有相关配置

PLIST_NAME="com.workbuddy.checkin"
PLIST_DEST="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
KEYCHAIN_SERVICE="com.workbuddy.checkin"
KEYCHAIN_ACCOUNT="screen-unlock"

echo "🗑  卸载 WorkBuddy 签到定时任务..."
echo ""

# 1. 卸载 launchd 定时任务
if [ -f "$PLIST_DEST" ]; then
    launchctl unload "$PLIST_DEST" 2>/dev/null
    rm -f "$PLIST_DEST"
    echo "✅ 定时任务已卸载"
else
    echo "ℹ️  未找到已安装的定时任务"
fi

# 2. 清理 pmset 定时唤醒
echo "⏰ 清理定时唤醒设置..."
sudo pmset repeat cancel
echo "✅ 定时唤醒已取消"

# 3. 清理 Keychain 中存储的密码
if security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" >/dev/null 2>&1; then
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" >/dev/null 2>&1
    echo "✅ Keychain 中的解锁密码已删除"
else
    echo "ℹ️  Keychain 中未找到已存储的密码"
fi

echo ""
echo "🎉 所有配置已清理完毕"
