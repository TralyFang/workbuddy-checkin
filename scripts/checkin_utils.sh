#!/bin/bash
# checkin_utils.sh - WorkBuddy 签到脚本工具方法

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

is_screen_locked() {
    python3 -c "
import subprocess
result = subprocess.run(['ioreg', '-n', 'Root', '-d1', '-a'], capture_output=True, text=True)
print('1' if 'CGSSessionScreenIsLocked' in result.stdout else '0')
" 2>/dev/null
}

ensure_accessibility_ready() {
    osascript <<'APPLESCRIPT' >/dev/null 2>&1
with timeout of 5 seconds
    tell application "System Events"
        count of processes
    end tell
end timeout
APPLESCRIPT
}

wait_for_accessibility_ready() {
    local max_attempts="${1:-5}"
    local attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
        if ensure_accessibility_ready; then
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done

    return 1
}

capture_screenshot() {
    local screenshot_file="$1"
    local window_id="$2"

    if [ -n "$window_id" ] && screencapture -x -l "$window_id" "$screenshot_file" 2>/dev/null; then
        return 0
    fi

    if [ -n "$window_id" ]; then
        warn "窗口截图失败，回退为全屏截图"
    else
        warn "未找到 WorkBuddy 窗口，回退为全屏截图"
    fi

    caffeinate -u -t 2
    sleep 2

    screencapture -x "$screenshot_file" 2>/dev/null
}

cleanup_checkin_runtime() {
    if [ -n "${CAFFEINATE_PID:-}" ]; then
        kill "$CAFFEINATE_PID" 2>/dev/null
        wait "$CAFFEINATE_PID" 2>/dev/null
    fi
    if [ -n "${RUN_LOCK_DIR:-}" ] && [ -d "$RUN_LOCK_DIR" ] && [ "${LOCK_OWNER_PID:-}" = "$$" ]; then
        rm -rf "$RUN_LOCK_DIR"
    fi
}

acquire_run_lock() {
    local existing_pid

    if mkdir "$RUN_LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" > "$RUN_LOCK_DIR/pid"
        LOCK_OWNER_PID=$$
        return 0
    fi

    if [ -f "$RUN_LOCK_DIR/pid" ]; then
        existing_pid=$(cat "$RUN_LOCK_DIR/pid" 2>/dev/null)
        if [ -n "$existing_pid" ] && ! kill -0 "$existing_pid" 2>/dev/null; then
            rm -rf "$RUN_LOCK_DIR"
            mkdir "$RUN_LOCK_DIR" 2>/dev/null || fail "清理过期运行锁后仍无法获取执行锁"
            printf '%s\n' "$$" > "$RUN_LOCK_DIR/pid"
            LOCK_OWNER_PID=$$
            return 0
        fi
    fi

    log "检测到已有签到实例正在运行，跳过本次执行"
    exit 0
}

checkin_require_dependencies() {
    require_commands osascript security python3 caffeinate screencapture swift
    if [ ! -x "$CLICLICK_BIN" ]; then
        fail "未找到 cliclick：$CLICLICK_BIN"
    fi
}

prepare_checkin_runtime() {
    acquire_run_lock
    caffeinate -dims -t "$CAFFEINATE_MAX_SECONDS" &
    CAFFEINATE_PID=$!
    trap cleanup_checkin_runtime EXIT
}

apply_random_delay() {
    local random_delay
    local delay_minutes
    local delay_seconds

    if [ "${SKIP_RANDOM_DELAY:-0}" = "1" ]; then
        return 0
    fi

    random_delay=$((RANDOM % (RANDOM_DELAY_MAX_SECONDS + 1)))
    delay_minutes=$((random_delay / 60))
    delay_seconds=$((random_delay % 60))

    log "随机延迟 ${delay_minutes}分${delay_seconds}秒后执行..."
    sleep "$random_delay"
}

print_step() {
    local current_step="$1"
    local total_steps="$2"
    local message="$3"

    echo "[${current_step}/${total_steps}] ${message}..."
}

wake_screen_and_unlock_if_needed() {
    local unlock_password

    caffeinate -u -t 2
    sleep 2

    if ! wait_for_accessibility_ready; then
        fail "辅助功能权限不可用，请先在当前解锁状态下运行 scripts/setup_permissions.sh 触发授权，再重试"
    fi

    if [ "$(is_screen_locked)" != "1" ]; then
        echo "  ✅ 屏幕未锁定"
        return 0
    fi

    echo "  🔓 检测到锁屏，尝试自动解锁..."
    unlock_password=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null)
    if [ -z "$unlock_password" ]; then
        fail "未找到 Keychain 中的密码，请运行 scripts/setup_keychain.sh 设置"
    fi

    osascript - "$unlock_password" <<'APPLESCRIPT' >/dev/null 2>&1 || fail "发送解锁密码失败，请先在当前解锁状态下运行 scripts/setup_permissions.sh 完成 System Events 授权"
on run argv
    tell application "System Events" to keystroke (item 1 of argv)
end run
APPLESCRIPT
    sleep 0.5
    osascript -e 'tell application "System Events" to keystroke return' >/dev/null 2>&1 \
        || fail "发送回车解锁失败，请先在当前解锁状态下运行 scripts/setup_permissions.sh 完成 System Events 授权"
    sleep 2

    if [ "$(is_screen_locked)" = "1" ]; then
        fail "已发送解锁密码，但屏幕仍处于锁定状态"
    fi

    echo "  ✅ 已完成自动解锁"
}

activate_workbuddy() {
    local wait_seconds="${1:-2}"

    osascript -e 'tell application "WorkBuddy" to activate' >/dev/null 2>&1 \
        || fail "激活 WorkBuddy 失败，请确认应用已安装且允许脚本控制"
    sleep "$wait_seconds"
}

click_at() {
    local coord="$1"
    local fail_message="$2"
    local wait_seconds="${3:-0}"

    "$CLICLICK_BIN" "c:${coord}" || fail "$fail_message"
    if [ "$wait_seconds" -gt 0 ] 2>/dev/null; then
        sleep "$wait_seconds"
    fi
}

take_workbuddy_screenshot() {
    local screenshot_file="$1"
    local window_id

    mkdir -p "$(dirname "$screenshot_file")"
    window_id=$(swift "$SCRIPT_DIR/get_window_id.swift" "WorkBuddy" 2>/dev/null)

    if [ -n "$window_id" ]; then
        echo "  找到 WorkBuddy 窗口 ID: $window_id"
    else
        warn "未找到 WorkBuddy 窗口 ID"
    fi

    if ! capture_screenshot "$screenshot_file" "$window_id"; then
        if [ "${SCREENSHOT_FAILURE_IS_FATAL:-0}" = "1" ]; then
            fail "截图失败"
        fi
        warn "截图失败，已跳过留痕"
        return 0
    fi

    echo "截图已保存: $screenshot_file"
}
