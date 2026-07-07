#!/bin/bash
# checkin_mac.sh - WorkBuddy macOS 签到自动化脚本
# 依赖: cliclick (brew install cliclick), screencapture (macOS 自带)
# 坐标标准：WorkBuddy放置右半屏获取的相对屏幕坐标。
# 可以把鼠标放置到对应位置，通过“cliclick p”来获取当前坐标

. "$(cd "$(dirname "$0")" && pwd)/common.sh"

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
    local max_attempts=5
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
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

cleanup() {
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

# 配置
SCREENSHOT_DIR="$PROJECT_DIR/screenshots"
LOG_DIR="$(cd "$(dirname "$0")/../logs" && mkdir -p "$(dirname "$0")/../logs" && pwd)"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
RANDOM_DELAY_MAX_SECONDS=5 # 从触发时间起向后随机执行的最大延迟秒数（当前为 5 秒）
CAFFEINATE_MAX_SECONDS=300   # 脚本执行期间保持系统唤醒的最长秒数（5 分钟）
RUN_LOCK_DIR="/tmp/workbuddy-checkin.lock" # 防止同一时间多个 launchd 实例并发执行
SCREENSHOT_FAILURE_IS_FATAL=0 # 截图用于留痕，失败时默认只记警告，不中断签到结果

# WorkBuddy 右半屏布局下的关键点击坐标
CANCEL_POPUP_COORD="1554,1406"   # 关闭可能遮挡头像点击的弹窗
AVATAR_ENTRY_COORD="1314,1405"   # 点击头像，打开签到弹窗
CHECKIN_BUTTON_COORD="1363,1006" # 点击弹窗中的“今日签到”按钮

require_command osascript
require_command security
require_command python3
require_command caffeinate
require_command screencapture
if [ ! -x "$CLICLICK_BIN" ]; then
    fail "未找到 cliclick：$CLICLICK_BIN"
fi

acquire_run_lock

# 防止 Mac 在脚本执行期间重新睡眠（最长保持 5 分钟）
caffeinate -dims -t "$CAFFEINATE_MAX_SECONDS" &
CAFFEINATE_PID=$!
trap cleanup EXIT

# 按配置随机延迟后执行，避免每次都在固定秒级时刻运行
if [ "${SKIP_RANDOM_DELAY:-0}" != "1" ]; then
    RANDOM_DELAY=$((RANDOM % (RANDOM_DELAY_MAX_SECONDS + 1)))
    DELAY_MINUTES=$((RANDOM_DELAY / 60))
    DELAY_SECONDS=$((RANDOM_DELAY % 60))
    log "随机延迟 ${DELAY_MINUTES}分${DELAY_SECONDS}秒后执行..."
    sleep $RANDOM_DELAY
fi

log "开始 WorkBuddy 签到..."

# 0. 唤醒屏幕并解锁（防止息屏/锁屏导致 GUI 操作失败）
echo "[0/5] 唤醒屏幕并检查锁屏状态..."
caffeinate -u -t 2
sleep 2

if ! wait_for_accessibility_ready; then
    fail "辅助功能权限不可用，请先在当前解锁状态下运行 scripts/setup_permissions.sh 触发授权，再重试"
fi

# 检测是否处于锁屏状态，如果是则自动解锁
SCREEN_LOCKED=$(is_screen_locked)

if [ "$SCREEN_LOCKED" = "1" ]; then
    echo "  🔓 检测到锁屏，尝试自动解锁..."
    UNLOCK_PWD=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null)
    if [ -n "$UNLOCK_PWD" ]; then
        osascript - "$UNLOCK_PWD" <<'APPLESCRIPT' >/dev/null 2>&1 || fail "发送解锁密码失败，请先在当前解锁状态下运行 scripts/setup_permissions.sh 完成 System Events 授权"
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
    else
        fail "未找到 Keychain 中的密码，请运行 scripts/setup_keychain.sh 设置"
    fi
else
    echo "  ✅ 屏幕未锁定"
fi

# 1. 激活 WorkBuddy 应用
echo "[1/5] 激活 WorkBuddy 应用..."
osascript -e 'tell application "WorkBuddy" to activate' >/dev/null 2>&1 \
    || fail "激活 WorkBuddy 失败，请确认应用已安装且允许脚本控制"
sleep 2

# 2. 点击取消弹窗坐标，避免遮挡后续头像点击
echo "[2/5] 点击坐标 (${CANCEL_POPUP_COORD})..."
"$CLICLICK_BIN" "c:${CANCEL_POPUP_COORD}" || fail "点击取消弹窗坐标失败"
sleep 1

# 3. 点击头像位置，打开签到弹窗
echo "[3/5] 点击坐标 (${AVATAR_ENTRY_COORD})..."
"$CLICLICK_BIN" "c:${AVATAR_ENTRY_COORD}" || fail "点击头像坐标失败"

# 4. 等待 3 秒后点击签到按钮
echo "[4/5] 等待 3 秒后点击坐标 (${CHECKIN_BUTTON_COORD})..."
sleep 3
"$CLICLICK_BIN" "c:${CHECKIN_BUTTON_COORD}" || fail "点击签到按钮坐标失败"

# 5. 等待 5 秒后截图保存
echo "[5/5] 等待 5 秒后截图..."
sleep 5

# 确保截图目录存在
mkdir -p "$SCREENSHOT_DIR"

# 截取 WorkBuddy 窗口
SCREENSHOT_FILE="${SCREENSHOT_DIR}/workbuddy_checkin_${TIMESTAMP}.png"

# 使用 Swift 调用 CGWindowListCopyWindowInfo 获取 WorkBuddy 窗口 ID
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WINDOW_ID=$(swift "$SCRIPT_DIR/get_window_id.swift" "WorkBuddy" 2>/dev/null)

if [ -n "$WINDOW_ID" ]; then
    echo "  找到 WorkBuddy 窗口 ID: $WINDOW_ID"
else
    echo "  ⚠️  警告: 未找到 WorkBuddy 窗口 ID"
fi

if ! capture_screenshot "$SCREENSHOT_FILE" "$WINDOW_ID"; then
    if [ "$SCREENSHOT_FAILURE_IS_FATAL" = "1" ]; then
        fail "截图失败"
    fi
    warn "截图失败，已跳过留痕"
else
    echo "截图已保存: $SCREENSHOT_FILE"
fi

log "WorkBuddy 签到完成！"
