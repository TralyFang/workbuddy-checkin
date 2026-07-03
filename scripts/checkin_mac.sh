#!/bin/bash
# checkin_mac.sh - WorkBuddy macOS 签到自动化脚本
# 依赖: cliclick (brew install cliclick), screencapture (macOS 自带)
# 坐标标准：WorkBuddy放置右半屏获取的相对屏幕坐标。
# 可以把鼠标放置到对应位置，通过“cliclick p”来获取当前坐标

# 配置
SCREENSHOT_DIR="$(cd "$(dirname "$0")/../screenshots" && pwd)"
LOG_DIR="$(cd "$(dirname "$0")/../logs" && mkdir -p "$(dirname "$0")/../logs" && pwd)"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# 防止 Mac 在脚本执行期间重新睡眠（最长保持 15 分钟）
caffeinate -dims -t 900 &
CAFFEINATE_PID=$!
trap "kill $CAFFEINATE_PID 2>/dev/null" EXIT

# 随机延迟 0~10 分钟（配合 launchd 在 8:05 触发，实际执行时间为 8:05~8:15，覆盖 8:10±5 分钟）
if [ "${SKIP_RANDOM_DELAY:-0}" != "1" ]; then
    RANDOM_DELAY=$((RANDOM % 600))
    DELAY_MINUTES=$((RANDOM_DELAY / 60))
    DELAY_SECONDS=$((RANDOM_DELAY % 60))
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 随机延迟 ${DELAY_MINUTES}分${DELAY_SECONDS}秒后执行..."
    sleep $RANDOM_DELAY
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始 WorkBuddy 签到..."

# 0. 唤醒屏幕并解锁（防止息屏/锁屏导致 GUI 操作失败）
echo "[0/5] 唤醒屏幕并检查锁屏状态..."
caffeinate -u -t 2
sleep 2

# 检测是否处于锁屏状态，如果是则自动解锁
SCREEN_LOCKED=$(python3 -c "
import subprocess
result = subprocess.run(['ioreg', '-n', 'Root', '-d1', '-a'], capture_output=True, text=True)
print('1' if 'CGSSessionScreenIsLocked' in result.stdout else '0')
" 2>/dev/null)

if [ "$SCREEN_LOCKED" = "1" ]; then
    echo "  🔓 检测到锁屏，尝试自动解锁..."
    UNLOCK_PWD=$(security find-generic-password -s "com.workbuddy.checkin" -a "screen-unlock" -w 2>/dev/null)
    if [ -n "$UNLOCK_PWD" ]; then
        osascript -e "tell application \"System Events\" to keystroke \"$UNLOCK_PWD\""
        sleep 0.5
        osascript -e 'tell application "System Events" to keystroke return'
        sleep 2
        echo "  ✅ 已发送解锁密码"
    else
        echo "  ⚠️  未找到 Keychain 中的密码，请运行 scripts/setup_keychain.sh 设置"
    fi
else
    echo "  ✅ 屏幕未锁定"
fi

# 1. 激活 WorkBuddy 应用
echo "[1/5] 激活 WorkBuddy 应用..."
osascript -e 'tell application "WorkBuddy" to activate'
sleep 2

# 2. 点击坐标 (1554, 1406) 避免有弹窗的情况下，点击头像无法弹出签到弹窗，先取消弹窗
echo "[2/5] 点击坐标 (1554, 1406)..."
cliclick c:1554,1406
sleep 1

# 3. 点击坐标 (1314, 1405) 头像位置
echo "[3/5] 点击坐标 (1314, 1405)..."
cliclick c:1314,1405

# 4. 等待 3 秒后点击坐标 (1363, 1006) 弹窗中的今日签到按钮
echo "[4/5] 等待 3 秒后点击坐标 (1363, 1006)..."
sleep 3
cliclick c:1363,1006

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
    screencapture -x -l "$WINDOW_ID" "$SCREENSHOT_FILE"
else
    echo "  ⚠️  警告: 未找到 WorkBuddy 窗口，回退为全屏截图"
    screencapture -x "$SCREENSHOT_FILE"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] WorkBuddy 签到完成！"
echo "截图已保存: $SCREENSHOT_FILE"
