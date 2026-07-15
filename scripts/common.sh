#!/bin/bash
# common.sh - WorkBuddy 脚本共享常量与通用辅助方法

# 脚本目录与项目根目录，供 install/uninstall/checkin 共用
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# launchd 定时任务标识与安装目标路径
PLIST_NAME="com.workbuddy.checkin"
PLIST_DEST="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

# Keychain 中保存自动解锁密码的 service/account 标识
KEYCHAIN_SERVICE="com.workbuddy.checkin"
KEYCHAIN_ACCOUNT="screen-unlock"

# 安装状态持久化目录，用于记录 WorkBuddy 最近一次写入的 pmset 配置
STATE_DIR="$HOME/Library/Application Support/WorkBuddyCheckin"
STATE_FILE="$STATE_DIR/install_state.env"

# pmset 重复唤醒事件的类型与生效日期
WAKE_EVENT_TYPE="wakeorpoweron"
WAKE_EVENT_DAYS="MTWRFSU"

# Homebrew 安装的 cliclick 绝对路径，避免 launchd 环境缺少 PATH
CLICLICK_BIN="/opt/homebrew/bin/cliclick"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1"
}

fail() {
    log "❌ $1" >&2
    exit 1
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        fail "缺少依赖命令：$1"
    fi
}

require_commands() {
    local cmd

    for cmd in "$@"; do
        require_command "$cmd"
    done
}

# 确保持久化状态目录存在
ensure_state_dir() {
    mkdir -p "$STATE_DIR"
}

# 读取上一次安装时保存的触发时间、唤醒时间和 pmset 签名
load_install_state() {
    if [ -f "$STATE_FILE" ]; then
        # shellcheck disable=SC1090
        . "$STATE_FILE"
        return 0
    fi
    return 1
}

# 保存当前安装写入的关键状态，供卸载和重装时做安全校验
save_install_state() {
    local trigger_time="$1"
    local wake_time="$2"
    local repeat_line="$3"

    ensure_state_dir
    cat > "$STATE_FILE" <<EOF
WORKBUDDY_TRIGGER_TIME="$trigger_time"
WORKBUDDY_WAKE_TIME="$wake_time"
WORKBUDDY_PMSET_REPEAT_LINE="$repeat_line"
EOF
}

# 删除本项目记录的安装状态，不影响其他系统配置
clear_install_state() {
    rm -f "$STATE_FILE"
}

# 读取当前系统中的第一条重复电源计划，供安装/卸载时比对来源
get_current_repeat_line() {
    pmset -g sched 2>/dev/null | awk '
        /^Repeating power events:/ { in_repeat=1; next }
        in_repeat && NF { gsub(/^[[:space:]]+/, "", $0); print; exit }
    '
}

# 统计当前系统中共有多少条重复电源计划，避免误判多任务场景
get_current_repeat_count() {
    pmset -g sched 2>/dev/null | awk '
        /^Repeating power events:/ { in_repeat=1; next }
        in_repeat && NF { count++ }
        END { print count + 0 }
    '
}

# 将 24 小时制的 pmset 时间格式化为 pmset -g sched 的展示样式
format_pmset_display_time() {
    date -j -f "%H:%M:%S" "$1" "+%-I:%M%p" 2>/dev/null
}

# 构造期望中的 pmset 重复电源计划签名，便于和系统当前配置做精确比对
build_pmset_repeat_line() {
    local wake_time="$1"
    local display_time

    display_time=$(format_pmset_display_time "$wake_time") || return 1
    printf "wakepoweron at %s every day" "$display_time"
}

# 使用 sudo 校验输入的登录密码是否有效，不修改任何系统配置
validate_login_password() {
    local password="$1"

    printf '%s\n' "$password" | sudo -S -k -v >/dev/null 2>&1
}

# 将已校验通过的登录密码写入 Keychain；如已存在则直接覆盖更新
save_keychain_password() {
    local password="$1"

    security add-generic-password -U -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w "$password" >/dev/null 2>&1
}
