#!/bin/bash
# setup_permissions.sh - 在用户可交互时预热 WorkBuddy 所需系统权限弹窗

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/common.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1"
}

prompt_accessibility_permission() {
    swift "$SCRIPT_DIR/request_accessibility.swift" 2>/dev/null
}

trigger_bash_accessibility_permission() {
    "$CLICLICK_BIN" p >/dev/null 2>&1
}

trigger_system_events_permission() {
    osascript <<'APPLESCRIPT' >/dev/null 2>&1
with timeout of 5 seconds
    tell application "System Events"
        keystroke ""
    end tell
end timeout
APPLESCRIPT
}

main() {
    echo "🔐 WorkBuddy 权限预热"
    echo "   将在当前解锁状态下主动触发系统授权检查："
    echo "   1. 辅助功能"
    echo "   2. 自动化（控制 System Events）"
    echo ""

    require_commands=(swift osascript)
    for cmd in "${require_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "❌ 缺少依赖命令：$cmd" >&2
            exit 1
        fi
    done
    if [ ! -x "$CLICLICK_BIN" ]; then
        echo "❌ 未找到 cliclick：$CLICLICK_BIN" >&2
        exit 1
    fi

    echo "1/2 触发 bash 辅助功能权限..."
    if prompt_accessibility_permission >/dev/null && trigger_bash_accessibility_permission; then
        echo "   ✅ bash 辅助功能权限已可用"
    else
        warn "已尝试触发 bash 辅助功能权限；如果出现“bash 想使用辅助功能来控制这台电脑”，请点击允许"
    fi

    echo "2/2 检查 System Events 自动化权限..."
    if trigger_system_events_permission; then
        echo "   ✅ System Events 自动化权限已可用"
    else
        warn "已尝试触发 System Events 自动化权限；如果弹出“允许控制 System Events”提示，请点击允许"
    fi

    echo ""
    echo "如刚完成授权，建议再手动执行一次："
    echo "SKIP_RANDOM_DELAY=1 $PROJECT_DIR/scripts/checkin_mac.sh"
}

main "$@"
