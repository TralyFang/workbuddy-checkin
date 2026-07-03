#!/bin/bash
# install.sh - 安装 WorkBuddy 签到定时任务
# 自动根据项目所在路径生成 launchd plist 并加载

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_NAME="com.workbuddy.checkin"
PLIST_DEST="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

KEYCHAIN_SERVICE="com.workbuddy.checkin"
KEYCHAIN_ACCOUNT="screen-unlock"

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
else
    echo -n "🔐 请输入 Mac 登录密码（用于自动解锁屏幕 + 设置定时唤醒）: "
    read -rs PASSWORD
    echo ""
    if [ -n "$PASSWORD" ]; then
        security add-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w "$PASSWORD"
        echo "  ✅ 密码已存储到 Keychain（加密）"
    else
        echo "  ⚠️  密码为空，跳过 Keychain（锁屏时将无法自动解锁）"
    fi
fi
echo ""

# 设置触发时间
echo -n "⏰ 请输入每天触发时间（格式 HH:MM，直接回车默认 08:05）: "
read -r TRIGGER_TIME
if [ -z "$TRIGGER_TIME" ]; then
    TRIGGER_TIME="08:05"
fi

# 解析小时和分钟
TRIGGER_HOUR=$(echo "$TRIGGER_TIME" | cut -d: -f1 | sed 's/^0//')
TRIGGER_MINUTE=$(echo "$TRIGGER_TIME" | cut -d: -f2 | sed 's/^0//')

# pmset 唤醒时间提前 1 分钟
WAKE_MINUTE=$((TRIGGER_MINUTE - 1))
WAKE_HOUR=$TRIGGER_HOUR
if [ $WAKE_MINUTE -lt 0 ]; then
    WAKE_MINUTE=59
    WAKE_HOUR=$((WAKE_HOUR - 1))
fi
WAKE_TIME=$(printf "%02d:%02d:00" $WAKE_HOUR $WAKE_MINUTE)

echo "  触发时间: $TRIGGER_TIME"
echo "  唤醒时间: $WAKE_TIME"
echo ""

# 设置 pmset 定时唤醒
echo "⏰ 设置每天 $WAKE_TIME 定时唤醒..."
echo "$PASSWORD" | sudo -S pmset repeat wakeorpoweron MTWRFSU "$WAKE_TIME" 2>/dev/null

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

# 加载定时任务
launchctl load "$PLIST_DEST"

echo ""
echo "✅ 定时任务已安装！"
echo "   每天 $WAKE_TIME 自动唤醒 Mac"
echo "   每天 $TRIGGER_TIME 触发脚本，加上随机延迟 0~10 分钟"
echo ""
echo "📋 常用命令:"
echo "   查看状态: launchctl list | grep workbuddy"
echo "   查看日志: cat $PROJECT_DIR/logs/checkin.log"
echo "   手动测试: SKIP_RANDOM_DELAY=1 $PROJECT_DIR/scripts/checkin_mac.sh"
echo "   卸载任务: $PROJECT_DIR/uninstall.sh"
