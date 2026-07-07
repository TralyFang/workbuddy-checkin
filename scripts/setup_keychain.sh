#!/bin/bash
# setup_keychain.sh - 将登录密码安全存储到 macOS Keychain
# 只需运行一次

. "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "🔐 WorkBuddy 签到 - 设置屏幕解锁密码"
echo "密码将安全存储在 macOS Keychain 中（加密存储，非明文）"
echo ""

# 检查是否已存在
if security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" >/dev/null 2>&1; then
    echo "⚠️  已存在已保存的密码，是否覆盖？(y/n)"
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "取消操作"
        exit 0
    fi
    # 删除旧的
    security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" >/dev/null 2>&1
fi

# 读取密码（不回显）
echo -n "请输入 Mac 登录密码: "
read -rs PASSWORD
echo ""

if [ -z "$PASSWORD" ]; then
    echo "❌ 密码不能为空"
    exit 1
fi

# 先校验密码，再存入 Keychain
if ! validate_login_password "$PASSWORD"; then
    echo "❌ 登录密码校验失败，请确认输入的是当前 Mac 登录密码"
    exit 1
fi

if save_keychain_password "$PASSWORD"; then
    echo "✅ 密码校验通过，已安全存储到 Keychain"
    echo "   服务名: $KEYCHAIN_SERVICE"
    echo "   账户名: $KEYCHAIN_ACCOUNT"
    echo ""
    echo "如需删除: security delete-generic-password -s '$KEYCHAIN_SERVICE' -a '$KEYCHAIN_ACCOUNT'"
else
    echo "❌ 存储失败"
    exit 1
fi
