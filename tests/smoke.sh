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

echo "OK"
