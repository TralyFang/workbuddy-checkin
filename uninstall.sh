#!/bin/bash
# uninstall.sh - 卸载 WorkBuddy 签到定时任务并清理所有相关配置

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/scripts/common.sh"

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
load_install_state >/dev/null 2>&1 || true
CURRENT_REPEAT_LINE=$(get_current_repeat_line)
CURRENT_REPEAT_COUNT=$(get_current_repeat_count)
if [ -n "${WORKBUDDY_PMSET_REPEAT_LINE:-}" ] && [ "$CURRENT_REPEAT_COUNT" -eq 1 ] && [ "$CURRENT_REPEAT_LINE" = "$WORKBUDDY_PMSET_REPEAT_LINE" ]; then
    if sudo pmset repeat cancel >/dev/null 2>&1; then
        echo "✅ 定时唤醒已取消"
        clear_install_state
    else
        echo "⚠️  取消定时唤醒失败，请手动执行 sudo pmset repeat cancel"
    fi
elif [ -n "$CURRENT_REPEAT_LINE" ]; then
    echo "⚠️  当前系统重复电源计划不是 WorkBuddy 创建的，已跳过取消：$CURRENT_REPEAT_LINE"
    clear_install_state
else
    echo "ℹ️  未检测到重复电源计划"
    clear_install_state
fi

# 3. 清理 Keychain 中存储的密码
if security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" >/dev/null 2>&1; then
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" >/dev/null 2>&1
    echo "✅ Keychain 中的解锁密码已删除"
else
    echo "ℹ️  Keychain 中未找到已存储的密码"
fi

echo ""
echo "🎉 所有配置已清理完毕"
