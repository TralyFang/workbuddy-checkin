#!/bin/bash
# checkin_mac.sh - WorkBuddy macOS 签到自动化脚本
# 依赖: cliclick (brew install cliclick), screencapture (macOS 自带)
# 坐标标准：WorkBuddy放置右半屏获取的相对屏幕坐标。
# 可以把鼠标放置到对应位置，通过“cliclick p”来获取当前坐标

. "$(cd "$(dirname "$0")" && pwd)/checkin_utils.sh"

# 配置
SCREENSHOT_DIR="$PROJECT_DIR/screenshots"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
TOTAL_STEPS=10
RANDOM_DELAY_MAX_SECONDS=5 # 从触发时间起向后随机执行的最大延迟秒数（当前为 5 秒）
CAFFEINATE_MAX_SECONDS=300   # 脚本执行期间保持系统唤醒的最长秒数（5 分钟）
RUN_LOCK_DIR="/tmp/workbuddy-checkin.lock" # 防止同一时间多个 launchd 实例并发执行
SCREENSHOT_FAILURE_IS_FATAL=0 # 截图用于留痕，失败时默认只记警告，不中断签到结果

# WorkBuddy 右半屏布局下的关键点击坐标
COLOSE_FULL_MODEL="2529,60" # 关闭全窗口查看文档模式
CANCEL_POPUP_COORD="1554,1406"   # 关闭可能遮挡头像点击的弹窗
AVATAR_ENTRY_COORD="1314,1405"   # 点击头像，打开签到弹窗
CHECKIN_BUTTON_COORD="1363,1006" # 点击弹窗中的“今日签到”按钮

main() {
    local screenshot_file

    checkin_require_dependencies
    prepare_checkin_runtime
    apply_random_delay

    log "开始 WorkBuddy 签到..."

    print_step 1 "$TOTAL_STEPS" "唤醒屏幕并检查锁屏状态"
    wake_screen_and_unlock_if_needed

    print_step 2 "$TOTAL_STEPS" "激活 WorkBuddy 应用"
    activate_workbuddy 2

    print_step 3 "$TOTAL_STEPS" "点击取消弹窗坐标 (${CANCEL_POPUP_COORD})"
    click_at "$CANCEL_POPUP_COORD" "点击取消弹窗坐标失败" 1

    print_step 4 "$TOTAL_STEPS" "点击文档窗口坐标 (${COLOSE_FULL_MODEL})"
    click_at "$COLOSE_FULL_MODEL" "点击关闭文档窗口坐标失败" 3

    print_step 5 "$TOTAL_STEPS" "再次激活 WorkBuddy 应用"
    activate_workbuddy 2

    print_step 6 "$TOTAL_STEPS" "第一次点击头像坐标 (${AVATAR_ENTRY_COORD})"
    click_at "$AVATAR_ENTRY_COORD" "点击头像坐标失败" 5

    print_step 7 "$TOTAL_STEPS" "再次点击取消弹窗坐标 (${CANCEL_POPUP_COORD})"
    click_at "$CANCEL_POPUP_COORD" "点击取消弹窗坐标失败" 1

    print_step 8 "$TOTAL_STEPS" "第二次点击头像坐标 (${AVATAR_ENTRY_COORD})"
    click_at "$AVATAR_ENTRY_COORD" "点击头像坐标失败" 5

    print_step 9 "$TOTAL_STEPS" "点击签到按钮坐标 (${CHECKIN_BUTTON_COORD})"
    click_at "$CHECKIN_BUTTON_COORD" "点击签到按钮坐标失败"

    print_step 10 "$TOTAL_STEPS" "等待 5 秒后截图"
    sleep 5
    screenshot_file="${SCREENSHOT_DIR}/workbuddy_checkin_${TIMESTAMP}.png"
    take_workbuddy_screenshot "$screenshot_file"

    log "WorkBuddy 签到完成！"
}

main "$@"
