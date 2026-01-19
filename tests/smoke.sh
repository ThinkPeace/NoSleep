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
stub_dir_running="$(mktemp -d)"
stub_dir_infinite="$(mktemp -d)"
stub_dir_timed="$(mktemp -d)"
stub_home="$(mktemp -d)"
trap 'rm -rf "$stub_dir" "$stub_dir_running" "$stub_dir_infinite" "$stub_dir_timed" "$stub_home"' EXIT

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

cat >"$stub_dir_running/launchctl" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "print" ]]; then
  cat <<'OUT'
state = running
pid = 4321
OUT
  exit 0
fi
exit 0
STUB
chmod +x "$stub_dir_running/launchctl"

cat >"$stub_dir_running/ps" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" == *"-o args="* ]]; then
  echo "/usr/bin/caffeinate -d -u -i -s -t 30"
  exit 0
fi
if [[ "$*" == *"-o etime="* ]]; then
  echo "00:00:05"
  exit 0
fi
exit 0
STUB
chmod +x "$stub_dir_running/ps"

cat >"$stub_dir_infinite/launchctl" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "print" ]]; then
  cat <<'OUT'
state = running
pid = 9876
OUT
  exit 0
fi
exit 0
STUB
chmod +x "$stub_dir_infinite/launchctl"

cat >"$stub_dir_infinite/ps" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" == *"-o args="* ]]; then
  echo "/usr/bin/caffeinate -d -u -i -s"
  exit 0
fi
if [[ "$*" == *"-o etime="* ]]; then
  echo "00:10"
  exit 0
fi
exit 0
STUB
chmod +x "$stub_dir_infinite/ps"

cat >"$stub_dir_timed/launchctl" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
chmod +x "$stub_dir_timed/launchctl"

if ! echo "$help_output" | grep -q "status"; then
  fail "help output missing status command"
fi
if ! echo "$help_output" | grep -q "stop"; then
  fail "help output missing stop command"
fi

status_output_no_job="$(PATH="$stub_dir:$PATH" "$NOSLEEP" status | strip_ansi)"
if ! echo "$status_output_no_job" | grep -q "当前没有"; then
  fail "status output missing 'no job' message"
fi
if echo "$status_output_no_job" | grep -q "外部阻止休眠"; then
  fail "status output should not include external assertions"
fi

status_output_running="$(PATH="$stub_dir_running:$PATH" "$NOSLEEP" status | strip_ansi)"
if ! echo "$status_output_running" | grep -q "✅ nosleep 正在运行"; then
  fail "status output missing running message"
fi
if ! echo "$status_output_running" | grep -q "剩余时间: 00:00:25"; then
  fail "status output missing remaining time"
fi

status_output_infinite="$(PATH="$stub_dir_infinite:$PATH" "$NOSLEEP" status | strip_ansi)"
if ! echo "$status_output_infinite" | grep -q "剩余时间: ∞"; then
  fail "status output missing infinite remaining time"
fi

timed_output="$(HOME="$stub_home" PATH="$stub_dir_timed:$PATH" "$NOSLEEP" 1s | strip_ansi)"
if echo "$timed_output" | grep -q "时间到"; then
  fail "timed output should not include finish message"
fi

stop_output="$(PATH="$stub_dir:$PATH" "$NOSLEEP" stop 2>&1 | strip_ansi)"
if ! echo "$stop_output" | grep -q "没有正在运行"; then
  fail "stop output missing 'no job' message"
fi

echo "OK"
