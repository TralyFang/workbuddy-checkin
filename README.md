# WorkBuddy 每日签到工具

自动完成 macOS 端 WorkBuddy 每日签到，解放双手，不再错过积分！

## 项目结构

```
workbuddy-checkin/
├── scripts/
│   ├── checkin_mac.sh          # macOS 签到主脚本
│   ├── get_window_id.swift     # Swift 工具：获取窗口 ID 用于精确截图
│   ├── request_accessibility.swift # Swift 工具：触发辅助功能权限检查/弹窗
│   ├── setup_permissions.sh    # 主动预热辅助功能 / 自动化权限弹窗
│   └── setup_keychain.sh       # 将登录密码存入 Keychain（首次运行）
├── install.sh                  # 一键安装定时任务（自动适配项目路径）
├── uninstall.sh                # 一键卸载定时任务
├── screenshots/                # 签到截图保存目录
├── logs/                       # 定时任务日志目录
└── README.md
```

## 依赖

- **cliclick** — 模拟鼠标点击（通过 Homebrew 安装）
- **screencapture** — macOS 自带截图工具
- **osascript** — macOS 自带 AppleScript 执行器
- **swift** — macOS 自带 Swift 编译器

### 安装 cliclick

```bash
brew install cliclick
```

## 签到流程

脚本 `scripts/checkin_mac.sh` 执行以下步骤：

1. **随机延迟** — 等待 0~3 分钟（从触发时间起向后随机 0~3 分钟执行）
2. **唤醒屏幕** — 通过 `caffeinate -u` 唤醒显示器，确保 GUI 操作可用
3. **激活 WorkBuddy** — 通过 osascript 将 WorkBuddy 置于前台
3. **点击坐标 (1554, 1406)** — 关闭可能存在的弹窗，避免遮挡
4. **点击坐标 (1314, 1405)** — 点击头像位置，打开签到弹窗
5. **等待 3 秒后点击坐标 (1363, 1006)** — 点击弹窗中的「今日签到」按钮
6. **等待 5 秒后截图** — 使用 Swift 获取 WorkBuddy 窗口 ID，精确截取窗口保存到 `screenshots/` 目录

> 坐标标准：WorkBuddy 放置右半屏获取的相对屏幕坐标。可通过 `cliclick p` 获取当前鼠标坐标。

## 使用方法

### 手动执行（跳过随机延迟）

```bash
SKIP_RANDOM_DELAY=1 ./scripts/checkin_mac.sh
```

### 手动执行（含随机延迟）

```bash
./scripts/checkin_mac.sh
```

## 定时任务配置

使用 macOS launchd + pmset 实现每天自动签到：
- **T-5 秒** — `pmset` 定时唤醒 Mac（即使处于睡眠状态）
- **T** — `launchd` 触发脚本，`caffeinate` 保持唤醒 + 自动解锁屏幕
- **T ~ T+3 分钟** — 随机延迟 0~3 分钟后执行签到

其中 T 为用户安装时设置的触发时间（默认 08:05）。

### 一键安装

```bash
./install.sh
```

安装过程会交互式完成：
1. 输入 Mac 登录密码（存入 Keychain，用于自动解锁屏幕 + sudo 设置唤醒）
2. 设置每天触发时间（格式 HH:MM，直接回车默认 08:05）
3. 自动设置 pmset 定时唤醒（提前 5 秒）
4. 如果检测到现有重复电源计划，会直接覆盖为 WorkBuddy 的定时唤醒配置
5. 生成 launchd plist 并校验后加载定时任务

重复安装时会自动从 Keychain 读取密码，无需重复输入。
安装完成后，脚本还会主动触发一次辅助功能和 `System Events` 自动化权限检查，尽量把授权弹窗放在当前可交互时机完成。

### 一键卸载

```bash
./uninstall.sh
```

卸载会清理：launchd 定时任务 + Keychain 密码。
如果当前 `pmset` 重复电源计划仍然与 WorkBuddy 安装记录一致，也会一并取消；如果检测到当前计划不是 WorkBuddy 创建的，则会跳过，避免误删其他自动化任务。

### 查看任务状态

```bash
launchctl list | grep workbuddy
```
### 主动执行下launchd，来触发权限弹窗

```bash
launchctl kickstart -k gui/$(id -u)/com.workbuddy.checkin
```

### 查看日志

```bash
cat logs/checkin.log        # 标准输出
cat logs/checkin_error.log  # 错误输出
```

### 主动触发权限弹窗

```bash
./scripts/setup_permissions.sh
```

建议在屏幕解锁、你本人正在电脑前时执行一次。它会尝试主动触发：
- 辅助功能权限检查/弹窗
- `System Events` 自动化授权弹窗

## 注意事项

- 定时任务需要在用户登录状态下执行（launchd 用户级任务）
- 需要授予终端/脚本「辅助功能」权限（系统设置 → 隐私与安全性 → 辅助功能）
- 需要授予「屏幕录制」权限（用于 screencapture 截图）
- 如果定时任务报“辅助功能权限不可用”或“发送解锁密码失败”，先在当前解锁状态下执行 `./scripts/setup_permissions.sh`
- 安装脚本会校验 `pmset` 和 `launchd` 是否真正配置成功，失败会直接退出，不会再误报“安装成功”
- 坐标基于 WorkBuddy 放置在屏幕右半部分的布局，如果窗口位置变化需要重新获取坐标
- 如果获取窗口 ID 失败，会回退为全屏截图并输出警告
