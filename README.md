# WorkBuddy 每日签到工具

自动完成 macOS 端 WorkBuddy 每日签到，解放双手，不再错过积分！

## 项目结构

```
workbuddy-checkin/
├── scripts/
│   ├── checkin_mac.sh          # macOS 签到主脚本
│   └── get_window_id.swift     # Swift 工具：获取窗口 ID 用于精确截图
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

1. **随机延迟** — 等待 0~60 分钟（配合定时任务实现 8:10 ± 30 分钟的随机签到时间）
2. **激活 WorkBuddy** — 通过 osascript 将 WorkBuddy 置于前台
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

使用 macOS launchd 实现每天自动签到，触发时间为 7:40 + 随机延迟 0~60 分钟 = 实际签到时间 **8:10 ± 30 分钟**。

### 一键安装

```bash
./install.sh
```

安装脚本会自动根据项目所在路径生成 plist 并加载到 launchd，无需手动修改路径。

### 查看任务状态

```bash
launchctl list | grep workbuddy
```

### 一键卸载

```bash
./uninstall.sh
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
