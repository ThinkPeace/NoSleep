# NoSleep Open Source Packaging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Package and publish the `nosleep` CLI with install/update/uninstall scripts, Release assets + sha256, bilingual README, and a Homebrew tap template.

**Architecture:** Single Bash CLI (`nosleep`) plus helper scripts in `scripts/`. Release assets are generated from tags (`vX.Y.Z`) and distributed via GitHub Releases; Homebrew formula references those assets. Install/update/uninstall scripts are self-contained to support `curl | bash`.

**Tech Stack:** Bash, macOS `caffeinate`, `curl`, `shasum`, GitHub Actions, Homebrew formula (Ruby).

---

### Task 1: Add a minimal smoke test harness

**Files:**
- Create: `tests/smoke.sh`

**Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NOSLEEP="$ROOT_DIR/nosleep"

fail() { echo "FAIL: $1"; exit 1; }
strip_ansi() { sed -E 's/\x1B\[[0-9;]*[mK]//g'; }

if [[ ! -x "$NOSLEEP" ]]; then
  fail "nosleep not found or not executable"
fi

help_output="$($NOSLEEP --help | strip_ansi)"
if ! echo "$help_output" | grep -q "nosleep - macOS 防休眠小工具"; then
  fail "help output missing title"
fi

set +e
run_output="$($NOSLEEP run 2>&1 | strip_ansi)"
status=$?
set -e
if [[ $status -eq 0 ]]; then
  fail "expected non-zero exit for 'run' without command"
fi
if ! echo "$run_output" | grep -q "请指定要运行的命令"; then
  fail "missing error message for 'run' without command"
fi

echo "OK"
```

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL with "nosleep not found or not executable"

**Step 3: Commit**

```bash
git add tests/smoke.sh
git commit -m "test: add smoke test harness"
```

---

### Task 2: Add the `nosleep` CLI (core behavior + update command)

**Files:**
- Create: `nosleep`

**Step 1: Write the failing test**

Add a minimal version check to the smoke test so it fails until `nosleep` implements `--version`:

```bash
version_output="$($NOSLEEP --version | strip_ansi)"
if ! echo "$version_output" | grep -q "nosleep version"; then
  fail "missing version output"
fi
```

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL with "missing version output"

**Step 3: Write minimal implementation**

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="dev"
REPO="ThinkPeace/NoSleep"

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

strip_ansi() { sed -E 's/\x1B\[[0-9;]*[mK]//g'; }

show_help() {
  echo -e "${BOLD}☕️  nosleep - macOS 防休眠小工具${NC}"
  echo "--------------------------------------------------------"
  echo -e "用法: ${GREEN}nosleep${NC} [模式] [时间/命令]"
  echo ""
  echo -e "${BOLD}核心功能:${NC}"
  echo "  防止 macOS 进入睡眠模式。支持倒计时、后台模式和命令跟随。"
  echo ""
  echo -e "${BOLD}参数说明:${NC}"
  echo -e "  ${CYAN}(无参数)${NC}      无限期保持屏幕常亮 (直到按 Ctrl+C 停止)"
  echo -e "  ${CYAN}<时间>${NC}        指定保持唤醒的时长 (支持 s=秒, m=分, h=时, d=天)"
  echo -e "  ${CYAN}bg${NC}            后台模式 (允许屏幕关闭，但系统不休眠 - 适合下载/挂机)"
  echo -e "  ${CYAN}run${NC}           运行模式 (在指定命令运行期间保持唤醒)"
  echo -e "  ${CYAN}update${NC}        升级到最新版本"
  echo -e "  ${CYAN}--version${NC}     显示版本号"
  echo -e "  ${CYAN}--help${NC}        显示此帮助信息"
  echo ""
  echo -e "${BOLD}使用示例:${NC}"
  echo -e "  1. 临时离开，保持屏幕常亮:"
  echo -e "     ${GREEN}nosleep${NC}"
  echo ""
  echo -e "  2. 保持屏幕亮 1 小时 30 分钟 (以下写法均可):"
  echo -e "     ${GREEN}nosleep 90m${NC}"
  echo -e "     ${GREEN}nosleep 1.5h${NC}"
  echo ""
  echo -e "  3. 挂机下载大文件 3 小时 (允许黑屏省电，但不断网):"
  echo -e "     ${GREEN}nosleep bg 3h${NC}"
  echo ""
  echo -e "  4. 执行备份脚本，备份期间不许休眠:"
  echo -e "     ${GREEN}nosleep run ./backup_script.sh${NC}"
  echo ""
}

show_version() {
  echo "nosleep version ${VERSION}"
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${YELLOW}❌ 仅支持 macOS${NC}"
    exit 1
  fi
  if ! command -v caffeinate >/dev/null 2>&1; then
    echo -e "${YELLOW}❌ 未找到 caffeinate，请确认在 macOS 上运行${NC}"
    exit 1
  fi
}

get_install_dir() {
  if [[ -d "/opt/homebrew/bin" ]]; then
    echo "/opt/homebrew/bin"
  else
    echo "/usr/local/bin"
  fi
}

need_sudo() {
  local target="$1"
  [[ ! -w "$(dirname "$target")" ]]
}

latest_release_json() {
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest"
}

extract_asset_url() {
  local json="$1"
  local name="$2"
  echo "$json" | grep -Eo 'https://[^\"]+' | grep "/${name}$" | head -n1
}

get_latest_version() {
  local json="$1"
  echo "$json" | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^\"]+)".*/\1/'
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

update_self() {
  local json
  json="$(latest_release_json)"
  local version
  version="$(get_latest_version "$json")"
  if [[ -z "$version" ]]; then
    echo -e "${YELLOW}❌ 无法解析最新版本${NC}"
    exit 2
  fi

  local asset_name="nosleep-${version}"
  local sha_name="nosleep-${version}.sha256"
  local asset_url
  local sha_url
  asset_url="$(extract_asset_url "$json" "$asset_name")"
  sha_url="$(extract_asset_url "$json" "$sha_name")"
  if [[ -z "$asset_url" || -z "$sha_url" ]]; then
    echo -e "${YELLOW}❌ 未找到发布资产，请检查 Release${NC}"
    exit 2
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  curl -fsSL -o "$tmpdir/$asset_name" "$asset_url"
  curl -fsSL -o "$tmpdir/$sha_name" "$sha_url"

  local expected
  expected="$(awk '{print $1}' "$tmpdir/$sha_name")"
  local actual
  actual="$(sha256_file "$tmpdir/$asset_name")"
  if [[ "$expected" != "$actual" ]]; then
    echo -e "${YELLOW}❌ 校验失败，已中止升级${NC}"
    exit 3
  fi

  local target
  target="$(command -v nosleep || true)"
  if [[ -z "$target" ]]; then
    target="$(get_install_dir)/nosleep"
  fi

  if need_sudo "$target"; then
    sudo install -m 755 "$tmpdir/$asset_name" "$target"
  else
    install -m 755 "$tmpdir/$asset_name" "$target"
  fi

  echo -e "${GREEN}✅ 已升级到版本 ${version}${NC}"
}

# --- entry ---
require_macos

if [[ $# -eq 0 ]]; then
  echo -e "${GREEN}☕️  Mac 将无限期保持清醒 (按 Ctrl+C 退出)...${NC}"
  caffeinate -d -u -i
  exit 0
fi

case "$1" in
  --help|-h|help)
    show_help
    exit 0
    ;;
  --version|-v)
    show_version
    exit 0
    ;;
  update)
    update_self
    exit 0
    ;;
  run)
    shift
    if [[ $# -eq 0 ]]; then
      echo -e "${YELLOW}❌ 错误: 请指定要运行的命令${NC}"
      echo "示例: nosleep run 'echo hello'"
      exit 1
    fi
    echo -e "${GREEN}☕️  正在运行命令并保持清醒:${NC} $*"
    caffeinate -d -i "$@"
    exit $?
    ;;
  bg)
    MODE="system"
    shift
    ;;
  *)
    MODE="display"
    ;;
 esac

ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  echo -e "${YELLOW}❌ 错误: 缺少时间参数${NC}"
  echo "请尝试输入 'nosleep --help' 查看用法。"
  exit 1
fi

NUMBER=$(echo "$ARG" | sed 's/[^0-9.]//g')
UNIT=$(echo "$ARG" | sed 's/[0-9.]//g')
SECONDS=0

if [[ -z "$NUMBER" ]]; then
  echo -e "${YELLOW}❌ 错误: 无法解析时间格式 '$ARG'${NC}"
  exit 1
fi

if [[ -z "$UNIT" ]]; then UNIT="s"; fi

case "$UNIT" in
  s|sec)  SECONDS=$(echo "$NUMBER" | awk '{print int($1)}') ;;
  m|min)  SECONDS=$(echo "$NUMBER" | awk '{print int($1 * 60)}') ;;
  h|hour) SECONDS=$(echo "$NUMBER" | awk '{print int($1 * 3600)}') ;;
  d|day)  SECONDS=$(echo "$NUMBER" | awk '{print int($1 * 86400)}') ;;
  *)
    echo -e "${YELLOW}❌ 错误: 未知的时间单位 '$UNIT'${NC}"
    exit 1
    ;;
 esac

if [[ "$SECONDS" -le 0 ]]; then
  echo -e "${YELLOW}❌ 错误: 时间必须大于 0${NC}"
  exit 1
fi

READABLE=""
if [[ "$UNIT" == "h" || "$UNIT" == "hour" ]]; then READABLE="$NUMBER 小时"; \
elif [[ "$UNIT" == "m" || "$UNIT" == "min" ]]; then READABLE="$NUMBER 分钟"; \
elif [[ "$UNIT" == "d" || "$UNIT" == "day" ]]; then READABLE="$NUMBER 天"; \
else READABLE="$SECONDS 秒"; fi

trap "echo -e '\\n🛑 已手动停止。'; exit" SIGINT

if [[ "${MODE}" == "system" ]]; then
  echo -e "${GREEN}☕️  系统将在后台运行 $READABLE${NC} (允许黑屏)"
  caffeinate -i -t "$SECONDS"
else
  echo -e "${GREEN}☕️  屏幕将常亮 $READABLE${NC} (按 Ctrl+C 提前取消)"
  caffeinate -d -u -t "$SECONDS"
fi

if [[ $? -eq 0 ]]; then
  echo -e "${CYAN}😴 时间到，恢复正常休眠策略。${NC}"
fi
```

**Step 4: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS with "OK"

**Step 5: Commit**

```bash
git add nosleep tests/smoke.sh
git commit -m "feat: add nosleep CLI"
```

---

### Task 3: Add install/update/uninstall scripts

**Files:**
- Create: `scripts/install.sh`
- Create: `scripts/update.sh`
- Create: `scripts/uninstall.sh`

**Step 1: Write the failing test**

Extend `tests/smoke.sh` to verify script files exist and are executable:

```bash
for f in scripts/install.sh scripts/update.sh scripts/uninstall.sh; do
  if [[ ! -x "$ROOT_DIR/$f" ]]; then
    fail "$f not found or not executable"
  fi
done
```

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL with "scripts/install.sh not found or not executable"

**Step 3: Write minimal implementation**

`scripts/install.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO="ThinkPeace/NoSleep"

get_install_dir() {
  if [[ -d "/opt/homebrew/bin" ]]; then
    echo "/opt/homebrew/bin"
  else
    echo "/usr/local/bin"
  fi
}

need_sudo() {
  local target="$1"
  [[ ! -w "$(dirname "$target")" ]]
}

latest_release_json() {
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest"
}

extract_asset_url() {
  local json="$1"
  local name="$2"
  echo "$json" | grep -Eo 'https://[^\"]+' | grep "/${name}$" | head -n1
}

get_latest_version() {
  local json="$1"
  echo "$json" | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^\"]+)".*/\1/'
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

main() {
  echo "⬇️  正在下载 nosleep..."

  local json
  json="$(latest_release_json)"
  local version
  version="$(get_latest_version "$json")"
  if [[ -z "$version" ]]; then
    echo "❌ 无法解析最新版本"
    exit 2
  fi

  local asset_name="nosleep-${version}"
  local sha_name="nosleep-${version}.sha256"
  local asset_url
  local sha_url
  asset_url="$(extract_asset_url "$json" "$asset_name")"
  sha_url="$(extract_asset_url "$json" "$sha_name")"
  if [[ -z "$asset_url" || -z "$sha_url" ]]; then
    echo "❌ 未找到发布资产，请检查 Release"
    exit 2
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  curl -fsSL -o "$tmpdir/$asset_name" "$asset_url"
  curl -fsSL -o "$tmpdir/$sha_name" "$sha_url"

  local expected
  expected="$(awk '{print $1}' "$tmpdir/$sha_name")"
  local actual
  actual="$(sha256_file "$tmpdir/$asset_name")"
  if [[ "$expected" != "$actual" ]]; then
    echo "❌ 校验失败，已中止安装"
    exit 3
  fi

  local target
  target="$(get_install_dir)/nosleep"

  if need_sudo "$target"; then
    sudo install -m 755 "$tmpdir/$asset_name" "$target"
  else
    install -m 755 "$tmpdir/$asset_name" "$target"
  fi

  echo "✅ 安装成功！输入 'nosleep --help' 查看用法。"
}

main "$@"
```

`scripts/update.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO="ThinkPeace/NoSleep"

get_install_dir() {
  if [[ -d "/opt/homebrew/bin" ]]; then
    echo "/opt/homebrew/bin"
  else
    echo "/usr/local/bin"
  fi
}

need_sudo() {
  local target="$1"
  [[ ! -w "$(dirname "$target")" ]]
}

latest_release_json() {
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest"
}

extract_asset_url() {
  local json="$1"
  local name="$2"
  echo "$json" | grep -Eo 'https://[^\"]+' | grep "/${name}$" | head -n1
}

get_latest_version() {
  local json="$1"
  echo "$json" | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^\"]+)".*/\1/'
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

main() {
  local json
  json="$(latest_release_json)"
  local version
  version="$(get_latest_version "$json")"
  if [[ -z "$version" ]]; then
    echo "❌ 无法解析最新版本"
    exit 2
  fi

  local asset_name="nosleep-${version}"
  local sha_name="nosleep-${version}.sha256"
  local asset_url
  local sha_url
  asset_url="$(extract_asset_url "$json" "$asset_name")"
  sha_url="$(extract_asset_url "$json" "$sha_name")"
  if [[ -z "$asset_url" || -z "$sha_url" ]]; then
    echo "❌ 未找到发布资产，请检查 Release"
    exit 2
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  curl -fsSL -o "$tmpdir/$asset_name" "$asset_url"
  curl -fsSL -o "$tmpdir/$sha_name" "$sha_url"

  local expected
  expected="$(awk '{print $1}' "$tmpdir/$sha_name")"
  local actual
  actual="$(sha256_file "$tmpdir/$asset_name")"
  if [[ "$expected" != "$actual" ]]; then
    echo "❌ 校验失败，已中止升级"
    exit 3
  fi

  local target
  target="$(command -v nosleep || true)"
  if [[ -z "$target" ]]; then
    target="$(get_install_dir)/nosleep"
  fi

  if need_sudo "$target"; then
    sudo install -m 755 "$tmpdir/$asset_name" "$target"
  else
    install -m 755 "$tmpdir/$asset_name" "$target"
  fi

  echo "✅ 已升级到版本 ${version}"
}

main "$@"
```

`scripts/uninstall.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

get_install_dir() {
  if [[ -d "/opt/homebrew/bin" ]]; then
    echo "/opt/homebrew/bin"
  else
    echo "/usr/local/bin"
  fi
}

need_sudo() {
  local target="$1"
  [[ ! -w "$(dirname "$target")" ]]
}

main() {
  local target
  target="$(command -v nosleep || true)"
  if [[ -z "$target" ]]; then
    target="$(get_install_dir)/nosleep"
  fi

  if [[ ! -e "$target" ]]; then
    echo "ℹ️  未找到已安装的 nosleep"
    exit 0
  fi

  if need_sudo "$target"; then
    sudo rm -f "$target"
  else
    rm -f "$target"
  fi

  echo "✅ 已卸载 nosleep"
}

main "$@"
```

**Step 4: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS with "OK"

**Step 5: Commit**

```bash
git add scripts/install.sh scripts/update.sh scripts/uninstall.sh tests/smoke.sh
git commit -m "feat: add install/update/uninstall scripts"
```

---

### Task 4: Update README (bilingual) and add release docs

**Files:**
- Modify: `README.md`
- Create: `docs/RELEASING.md`

**Step 1: Write the failing test**

Add a README check to the smoke test:

```bash
if ! grep -q "brew install thinkpeace/tap/nosleep" "$ROOT_DIR/README.md"; then
  fail "README missing brew install command"
fi
```

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL with "README missing brew install command"

**Step 3: Write minimal implementation**

`README.md` (outline):

```markdown
# ☕️ nosleep - macOS 防休眠命令行工具 / NoSleep

简单、通俗易懂的 macOS 防休眠工具，封装自原生 `caffeinate` 命令。
一行命令，让你的 Mac 保持清醒。

A simple macOS no-sleep wrapper around `caffeinate`.

## ✨ 特点 / Features
- 🇨🇳 全中文提示，直观易懂
- ⏱ 支持 s/m/h/d 以及小数时间
- 👻 后台模式允许黑屏省电
- 🚀 命令跟随模式
- ♻️ 支持升级更新

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
nosleep run ./backup_script.sh
```
```

`docs/RELEASING.md`:

```markdown
# Releasing NoSleep

1. Ensure `nosleep` and scripts are ready on `main`.
2. Tag a release: `git tag vX.Y.Z`.
3. Push tag: `git push origin vX.Y.Z`.
4. GitHub Actions will upload assets:
   - `nosleep-X.Y.Z`
   - `nosleep-X.Y.Z.sha256`
5. Update Homebrew tap formula to use the new asset + sha256.
```

**Step 4: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS with "OK"

**Step 5: Commit**

```bash
git add README.md docs/RELEASING.md tests/smoke.sh
git commit -m "docs: update README and release notes"
```

---

### Task 5: Add GitHub Actions release workflow

**Files:**
- Create: `.github/workflows/release.yml`

**Step 1: Write the failing test**

Add a workflow existence check to `tests/smoke.sh`:

```bash
if [[ ! -f "$ROOT_DIR/.github/workflows/release.yml" ]]; then
  fail "release workflow missing"
fi
```

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL with "release workflow missing"

**Step 3: Write minimal implementation**

```yaml
name: release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Prepare assets
        run: |
          version="${GITHUB_REF_NAME#v}"
          mkdir -p dist
          cp nosleep "dist/nosleep-${version}"
          sed -i.bak "s/^VERSION=\".*\"/VERSION=\"${version}\"/" "dist/nosleep-${version}"
          rm -f "dist/nosleep-${version}.bak"
          shasum -a 256 "dist/nosleep-${version}" > "dist/nosleep-${version}.sha256"

      - name: Publish Release Assets
        uses: softprops/action-gh-release@v2
        with:
          files: |
            dist/nosleep-*
```

**Step 4: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS with "OK"

**Step 5: Commit**

```bash
git add .github/workflows/release.yml tests/smoke.sh
git commit -m "ci: add release workflow"
```

---

### Task 6: Add Homebrew formula template

**Files:**
- Create: `homebrew/nosleep.rb`

**Step 1: Write the failing test**

Extend the smoke test:

```bash
if [[ ! -f "$ROOT_DIR/homebrew/nosleep.rb" ]]; then
  fail "homebrew formula template missing"
fi
```

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL with "homebrew formula template missing"

**Step 3: Write minimal implementation**

```ruby
class Nosleep < Formula
  desc "macOS no-sleep CLI wrapper around caffeinate"
  homepage "https://github.com/ThinkPeace/NoSleep"
  url "https://github.com/ThinkPeace/NoSleep/releases/download/vX.Y.Z/nosleep-X.Y.Z"
  sha256 "REPLACE_WITH_SHA256"
  version "X.Y.Z"

  def install
    bin.install "nosleep-X.Y.Z" => "nosleep"
  end

  test do
    system "#{bin}/nosleep", "--version"
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS with "OK"

**Step 5: Commit**

```bash
git add homebrew/nosleep.rb tests/smoke.sh
git commit -m "docs: add homebrew formula template"
```

---

### Task 7: Verify

**Files:**
- Test: `tests/smoke.sh`

**Step 1: Run full smoke test**

Run: `bash tests/smoke.sh`
Expected: PASS with "OK"

**Step 2: Commit (if needed)**

```bash
git status --short
```
Expected: clean

