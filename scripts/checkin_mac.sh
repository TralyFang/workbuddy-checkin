#!/bin/bash
# checkin_mac.sh - WorkBuddy macOS 签到自动化脚本
# 依赖: cliclick (brew install cliclick), screencapture (macOS 自带)
# 坐标标准：WorkBuddy放置右半屏获取的相对屏幕坐标。
# 可以把鼠标放置到对应位置，通过“cliclick p”来获取当前坐标

# 配置
SCREENSHOT_DIR="$(cd "$(dirname "$0")/../screenshots" && pwd)"
LOG_DIR="$(cd "$(dirname "$0")/../logs" && mkdir -p "$(dirname "$0")/../logs" && pwd)"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# 随机延迟 0~60 分钟（配合 launchd 在 7:40 触发，实际执行时间为 7:40~8:40，覆盖 8:10±30 分钟）
if [ "${SKIP_RANDOM_DELAY:-0}" != "1" ]; then
    RANDOM_DELAY=$((RANDOM % 3600))
    DELAY_MINUTES=$((RANDOM_DELAY / 60))
    DELAY_SECONDS=$((RANDOM_DELAY % 60))
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 随机延迟 ${DELAY_MINUTES}分${DELAY_SECONDS}秒后执行..."
    sleep $RANDOM_DELAY
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始 WorkBuddy 签到..."

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
