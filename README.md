# WorkBuddy 每日签到工具

自动完成 macOS 端 WorkBuddy 每日签到，解放双手，不再错过积分！

## 项目结构

```
workbuddy-checkin/
├── scripts/
│   ├── checkin_mac.sh          # macOS 签到主脚本
│   ├── get_window_id.swift     # Swift 工具：获取窗口 ID 用于精确截图
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

1. **随机延迟** — 等待 0~10 分钟（配合定时任务实现 8:10 ± 5 分钟的随机签到时间）
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
- **T-1 分钟** — `pmset` 定时唤醒 Mac（即使处于睡眠状态）
- **T** — `launchd` 触发脚本，`caffeinate` 保持唤醒 + 自动解锁屏幕
- **T ~ T+10 分钟** — 随机延迟 0~10 分钟后执行签到

其中 T 为用户安装时设置的触发时间（默认 08:05）。

### 一键安装

```bash
./install.sh
```

安装过程会交互式完成：
1. 输入 Mac 登录密码（存入 Keychain，用于自动解锁屏幕 + sudo 设置唤醒）
2. 设置每天触发时间（格式 HH:MM，直接回车默认 08:05）
3. 自动设置 pmset 定时唤醒（提前 1 分钟）
4. 生成 launchd plist 并加载定时任务

重复安装时会自动从 Keychain 读取密码，无需重复输入。

### 一键卸载

```bash
./uninstall.sh
```

卸载会清理：launchd 定时任务 + pmset 唤醒 + Keychain 密码，全部干净移除。

### 查看任务状态

```bash
launchctl list | grep workbuddy
```

### 查看日志

```bash
cat logs/checkin.log        # 标准输出
cat logs/checkin_error.log  # 错误输出
```

## 注意事项

- 定时任务需要在用户登录状态下执行（launchd 用户级任务）
- 需要授予终端/脚本「辅助功能」权限（系统设置 → 隐私与安全性 → 辅助功能）
- 需要授予「屏幕录制」权限（用于 screencapture 截图）
- 坐标基于 WorkBuddy 放置在屏幕右半部分的布局，如果窗口位置变化需要重新获取坐标
- 如果获取窗口 ID 失败，会回退为全屏截图并输出警告
