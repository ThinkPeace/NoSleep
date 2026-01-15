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
if ! echo "$help_output" | grep -q "网络不断"; then
  fail "help output missing network wording"
fi

version_output="$($NOSLEEP --version | strip_ansi)"
if ! echo "$version_output" | grep -q "nosleep version"; then
  fail "missing version output"
fi

for f in scripts/install.sh scripts/update.sh scripts/uninstall.sh; do
  if [[ ! -x "$ROOT_DIR/$f" ]]; then
    fail "$f not found or not executable"
  fi
done

if ! grep -q "brew install thinkpeace/tap/nosleep" "$ROOT_DIR/README.md"; then
  fail "README missing brew install command"
fi
if ! grep -q "系统不休眠" "$ROOT_DIR/README.md"; then
  fail "README missing system awake wording"
fi
if ! grep -q "nosleep status" "$ROOT_DIR/README.md"; then
  fail "README missing status command"
fi
if ! grep -q "nosleep stop" "$ROOT_DIR/README.md"; then
  fail "README missing stop command"
fi

if [[ ! -f "$ROOT_DIR/.github/workflows/release.yml" ]]; then
  fail "release workflow missing"
fi

if [[ ! -f "$ROOT_DIR/homebrew/nosleep.rb" ]]; then
  fail "homebrew formula template missing"
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

stub_dir="$(mktemp -d)"
trap 'rm -rf "$stub_dir"' EXIT

cat >"$stub_dir/launchctl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
if [[ "$cmd" == "print" ]]; then
  exit 1
fi
if [[ "$cmd" == "bootout" ]]; then
  exit 1
fi
exit 0
STUB
chmod +x "$stub_dir/launchctl"

cat >"$stub_dir/pmset" <<'STUB'
#!/usr/bin/env bash
cat <<'OUT'
Assertion status system-wide:
   PreventUserIdleSystemSleep 1
Listed by owning process:
  pid 9999(SomeApp): [0x00000001] 00:00:10 PreventUserIdleSystemSleep named: "SomeApp"
OUT
STUB
chmod +x "$stub_dir/pmset"

if ! echo "$help_output" | grep -q "status"; then
  fail "help output missing status command"
fi
if ! echo "$help_output" | grep -q "stop"; then
  fail "help output missing stop command"
fi

status_output="$(PATH="$stub_dir:$PATH" "$NOSLEEP" status | strip_ansi)"
if ! echo "$status_output" | grep -q "当前没有"; then
  fail "status output missing 'no job' message"
fi
if ! echo "$status_output" | grep -q "SomeApp"; then
  fail "status output missing external assertion"
fi

stop_output="$(PATH="$stub_dir:$PATH" "$NOSLEEP" stop 2>&1 | strip_ansi)"
if ! echo "$stop_output" | grep -q "没有正在运行"; then
  fail "stop output missing 'no job' message"
fi

echo "OK"
