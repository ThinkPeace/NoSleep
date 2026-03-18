# ☕️ nosleep - macOS 防休眠命令行工具 / NoSleep

简单、通俗易懂的 macOS 防休眠工具，封装自原生 `caffeinate` 命令。
一行命令，让你的 Mac 保持清醒。

A simple macOS no-sleep wrapper around `caffeinate`.

[访问官网/ Visit the official site ](https://restless-code-ninjas.mynocode.host/)

## ✨ 特点 / Features
- 🇨🇳 全中文提示，直观易懂
- ⏱ 支持 s/m/h/d 以及小数时间
- 👻 后台模式允许黑屏省电
- 🚀 命令跟随模式
- ♻️ 支持升级更新
- 🔌 默认/定时模式保持系统不休眠、网络不断；bg 允许黑屏但系统不休眠

## 📦 安装 / Installation

### 方式一：一行命令安装
```bash
curl -fsSL https://raw.githubusercontent.com/ThinkPeace/NoSleep/main/scripts/install.sh | bash
```

### 方式二：Homebrew
```bash
brew install thinkpeace/tap/nosleep
```

## 🔄 升级 / Update

```bash
nosleep update
# or
curl -fsSL https://raw.githubusercontent.com/ThinkPeace/NoSleep/main/scripts/update.sh | bash
```

## 🧹 卸载 / Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/ThinkPeace/NoSleep/main/scripts/uninstall.sh | bash
```

## 🚀 使用示例 / Usage

```bash
nosleep
nosleep 90m
nosleep 1.5h
nosleep bg 3h
nosleep status
nosleep stop 1
nosleep run ./backup_script.sh
```
