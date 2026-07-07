#!/bin/bash
# install.sh - 安装 WorkBuddy 签到定时任务
# 自动根据项目所在路径生成 launchd plist 并加载

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/scripts/common.sh"

abort_install() {
    echo "❌ $1" >&2
    exit 1
}

prompt_for_password() {
    echo -n "🔐 请输入 Mac 登录密码（用于自动解锁屏幕 + 设置定时唤醒）: "
    read -rs PASSWORD
    echo ""
    [ -n "$PASSWORD" ] || abort_install "密码不能为空，否则无法自动解锁和设置定时唤醒"
    validate_login_password "$PASSWORD" || abort_install "登录密码校验失败，请重新运行安装脚本并输入正确密码"
    save_keychain_password "$PASSWORD" || abort_install "密码写入 Keychain 失败"
    echo "  ✅ 密码校验通过，已存储到 Keychain（加密）"
}

validate_trigger_time() {
    local trigger_time="$1"

    [[ "$trigger_time" =~ ^([01]?[0-9]|2[0-3]):([0-5][0-9])$ ]]
}

rollback_install() {
    local exit_code=$?
    local current_repeat_count
    local current_repeat_line

    if [ $exit_code -eq 0 ] || [ "${PMSET_UPDATED:-0}" -ne 1 ]; then
        exit $exit_code
    fi

    current_repeat_line=$(get_current_repeat_line)
    current_repeat_count=$(get_current_repeat_count)
    if [ "$current_repeat_count" -eq 1 ] && [ "$current_repeat_line" = "${EXPECTED_PMSET_REPEAT_LINE:-}" ]; then
        if [ "${HAD_PREVIOUS_WORKBUDDY_STATE:-0}" -eq 1 ] && [ -n "${PREVIOUS_WORKBUDDY_WAKE_TIME:-}" ]; then
            printf '%s\n' "$PASSWORD" | sudo -S -k pmset repeat "$WAKE_EVENT_TYPE" "$WAKE_EVENT_DAYS" "$PREVIOUS_WORKBUDDY_WAKE_TIME" >/dev/null 2>&1 || true
        else
            printf '%s\n' "$PASSWORD" | sudo -S -k pmset repeat cancel >/dev/null 2>&1 || true
        fi
    fi

    exit $exit_code
}

trap rollback_install EXIT

echo "📦 WorkBuddy 签到定时任务安装器"
echo "项目路径: $PROJECT_DIR"
echo ""

# 确保目录存在
mkdir -p "$PROJECT_DIR/logs"
mkdir -p "$PROJECT_DIR/screenshots"

# 如果已安装，先卸载
if launchctl list | grep -q "$PLIST_NAME" 2>/dev/null; then
    echo "⏹  卸载旧的定时任务..."
    launchctl unload "$PLIST_DEST" 2>/dev/null
fi

# 获取 Mac 登录密码（用于 Keychain 存储和 sudo 操作）
if security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" >/dev/null 2>&1; then
    echo "🔐 已从 Keychain 读取解锁密码"
    PASSWORD=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null)
    if ! validate_login_password "$PASSWORD"; then
        echo "  ⚠️  Keychain 中保存的密码校验失败，需要重新输入"
        prompt_for_password
    fi
else
    prompt_for_password
fi
echo ""

# 设置触发时间
echo -n "⏰ 请输入每天触发时间（格式 HH:MM，直接回车默认 08:05）: "
read -r TRIGGER_TIME
if [ -z "$TRIGGER_TIME" ]; then
    TRIGGER_TIME="08:05"
fi
if ! validate_trigger_time "$TRIGGER_TIME"; then
    abort_install "触发时间格式无效，请使用 HH:MM，例如 08:05"
fi

# 解析小时、分钟，并将 pmset 唤醒时间提前 5 秒
IFS=':' read -r RAW_TRIGGER_HOUR RAW_TRIGGER_MINUTE RAW_TRIGGER_SECOND <<< "$TRIGGER_TIME"
RAW_TRIGGER_SECOND=${RAW_TRIGGER_SECOND:-0}

TRIGGER_HOUR=$((10#$RAW_TRIGGER_HOUR))
TRIGGER_MINUTE=$((10#$RAW_TRIGGER_MINUTE))
TRIGGER_SECOND=$((10#$RAW_TRIGGER_SECOND))

TRIGGER_TOTAL_SECONDS=$((TRIGGER_HOUR * 3600 + TRIGGER_MINUTE * 60 + TRIGGER_SECOND))
WAKE_TOTAL_SECONDS=$((TRIGGER_TOTAL_SECONDS - 5))
if [ $WAKE_TOTAL_SECONDS -lt 0 ]; then
    WAKE_TOTAL_SECONDS=$((WAKE_TOTAL_SECONDS + 24 * 3600))
fi

WAKE_HOUR=$((WAKE_TOTAL_SECONDS / 3600))
WAKE_MINUTE=$(((WAKE_TOTAL_SECONDS % 3600) / 60))
WAKE_SECOND=$((WAKE_TOTAL_SECONDS % 60))
WAKE_TIME=$(printf "%02d:%02d:%02d" $WAKE_HOUR $WAKE_MINUTE $WAKE_SECOND)

echo "  触发时间: $TRIGGER_TIME"
echo "  唤醒时间: $WAKE_TIME"
echo ""

EXPECTED_PMSET_REPEAT_LINE=$(build_pmset_repeat_line "$WAKE_TIME") \
    || abort_install "生成 pmset 校验信息失败"
CURRENT_REPEAT_LINE=$(get_current_repeat_line)
CURRENT_REPEAT_COUNT=$(get_current_repeat_count)
load_install_state >/dev/null 2>&1 || true
HAD_PREVIOUS_WORKBUDDY_STATE=0
PREVIOUS_WORKBUDDY_WAKE_TIME=""
if [ -n "${WORKBUDDY_PMSET_REPEAT_LINE:-}" ]; then
    HAD_PREVIOUS_WORKBUDDY_STATE=1
    PREVIOUS_WORKBUDDY_WAKE_TIME="${WORKBUDDY_WAKE_TIME:-}"
fi

if [ "$CURRENT_REPEAT_COUNT" -gt 0 ] && {
    [ "$CURRENT_REPEAT_COUNT" -ne 1 ] || [ "${WORKBUDDY_PMSET_REPEAT_LINE:-}" != "$CURRENT_REPEAT_LINE" ];
}; then
    echo "⚠️  检测到现有重复电源计划：$CURRENT_REPEAT_LINE"
    echo "   将主动覆盖为 WorkBuddy 的定时唤醒配置"
fi

# 设置 pmset 定时唤醒
echo "⏰ 设置每天 $WAKE_TIME 定时唤醒..."
if ! printf '%s\n' "$PASSWORD" | sudo -S -k pmset repeat "$WAKE_EVENT_TYPE" "$WAKE_EVENT_DAYS" "$WAKE_TIME" >/dev/null 2>&1; then
    abort_install "pmset 定时唤醒设置失败，请确认登录密码正确且当前账户具备 sudo 权限"
fi
PMSET_UPDATED=1

CURRENT_REPEAT_LINE=$(get_current_repeat_line)
CURRENT_REPEAT_COUNT=$(get_current_repeat_count)
if [ "$CURRENT_REPEAT_COUNT" -ne 1 ] || [ "$CURRENT_REPEAT_LINE" != "$EXPECTED_PMSET_REPEAT_LINE" ]; then
    abort_install "pmset 校验失败，当前重复电源计划为：${CURRENT_REPEAT_LINE:-<空>}"
fi

# 生成 plist 文件
cat > "$PLIST_DEST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${PROJECT_DIR}/scripts/checkin_mac.sh</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>${TRIGGER_HOUR}</integer>
        <key>Minute</key>
        <integer>${TRIGGER_MINUTE}</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>${PROJECT_DIR}/logs/checkin.log</string>

    <key>StandardErrorPath</key>
    <string>${PROJECT_DIR}/logs/checkin_error.log</string>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLIST

if ! plutil -lint "$PLIST_DEST" >/dev/null 2>&1; then
    abort_install "生成的 launchd plist 无效：$PLIST_DEST"
fi

# 加载定时任务
if ! launchctl load "$PLIST_DEST" >/dev/null 2>&1; then
    abort_install "launchd 定时任务加载失败：$PLIST_DEST"
fi

save_install_state "$TRIGGER_TIME" "$WAKE_TIME" "$EXPECTED_PMSET_REPEAT_LINE"
trap - EXIT

echo ""
echo "🔐 预热系统权限弹窗（辅助功能 / 自动化）..."
if ! "$PROJECT_DIR/scripts/setup_permissions.sh"; then
    echo "⚠️  权限预热未完全通过，请按系统提示授权后，再手动执行一次 scripts/setup_permissions.sh"
fi

echo ""
echo "✅ 定时任务已安装！"
echo "   每天 $WAKE_TIME 自动唤醒 Mac"
echo "   每天 $TRIGGER_TIME 触发脚本，加上随机延迟 0~3 分钟"
echo ""
echo "📋 常用命令:"
echo "   查看状态: launchctl list | grep workbuddy"
echo "   查看日志: cat $PROJECT_DIR/logs/checkin.log"
echo "   手动测试: SKIP_RANDOM_DELAY=1 $PROJECT_DIR/scripts/checkin_mac.sh"
echo "   卸载任务: $PROJECT_DIR/uninstall.sh"
