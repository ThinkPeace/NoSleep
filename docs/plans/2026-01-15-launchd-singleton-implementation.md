# Launchd Singleton NoSleep Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Switch `nosleep` to a single user-level launchd job so default/timed modes run in the background, and add `status`/`stop` commands that also surface external sleep-preventing assertions.

**Architecture:** Use a fixed LaunchAgent label (e.g., `com.thinkpeace.nosleep`) under `~/Library/LaunchAgents`. Each `nosleep` start rewrites the plist, `launchctl bootout` the old job, then `launchctl bootstrap` the new job. `status` reads `launchctl print gui/$UID/<label>` to show PID/args and `pmset -g assertions` to list external blockers. `stop` unloads the job and removes the plist.

**Tech Stack:** Bash, macOS `launchctl`, `caffeinate`, `pmset`.

### Task 1: Add failing CLI tests for new commands and help text

**Files:**
- Modify: `tests/smoke.sh`

**Step 1: Write the failing test**

Add stubbed `launchctl`/`pmset` and new assertions near the end of `tests/smoke.sh`:

```bash
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
```

**Step 2: Run test to verify it fails**

Run: `./tests/smoke.sh`
Expected: FAIL with missing `status/stop` help text and/or unknown command behavior.

**Step 3: Commit**

```bash
git add tests/smoke.sh
git commit -m "test: add status/stop smoke checks"
```

### Task 2: Implement launchd-backed start/status/stop and help output

**Files:**
- Modify: `nosleep`

**Step 1: Write the failing test**

Use the failing tests from Task 1.

**Step 2: Write minimal implementation**

Add launchd helpers and new commands to `nosleep`:

```bash
LAUNCHD_LABEL="com.thinkpeace.nosleep"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"

launchd_bootout() {
  launchctl bootout "gui/$UID/$LAUNCHD_LABEL" >/dev/null 2>&1 || true
}

launchd_bootstrap() {
  launchctl bootstrap "gui/$UID" "$LAUNCHD_PLIST" >/dev/null 2>&1
}

write_plist() {
  local -a args=("$@")
  mkdir -p "$(dirname "$LAUNCHD_PLIST")"
  cat >"$LAUNCHD_PLIST" <<'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LAUNCHD_LABEL</string>
  <key>ProgramArguments</key>
  <array>
$(printf '    <string>%s</string>\n' "${args[@]}")
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
PLISTEOF
}

start_launchd() {
  local -a args=("/usr/bin/caffeinate" "$@")
  write_plist "${args[@]}"
  launchd_bootout
  launchd_bootstrap
}

status_launchd() {
  if ! launchctl print "gui/$UID/$LAUNCHD_LABEL" >/dev/null 2>&1; then
    echo -e "${YELLOW}ℹ️  当前没有运行中的 nosleep 任务。${NC}"
  else
    local info
    info="$(launchctl print "gui/$UID/$LAUNCHD_LABEL")"
    local pid
    pid="$(echo "$info" | awk -F' = ' '/pid =/{print $2; exit}')"
    echo -e "${GREEN}✅ nosleep 正在运行${NC}"
    echo "ID: 1"
    echo "PID: ${pid:-unknown}"
    echo "Label: $LAUNCHD_LABEL"
  fi

  echo ""
  echo -e "${BOLD}外部阻止休眠的进程:${NC}"
  pmset -g assertions | sed -n '/Listed by owning process:/,$p'
}

stop_launchd() {
  if ! launchctl print "gui/$UID/$LAUNCHD_LABEL" >/dev/null 2>&1; then
    echo -e "${YELLOW}ℹ️  没有正在运行的 nosleep 任务。${NC}"
    return 0
  fi
  launchd_bootout
  rm -f "$LAUNCHD_PLIST"
  echo -e "${GREEN}✅ 已停止 nosleep。${NC}"
}
```

Update command dispatch:

```bash
  status)
    status_launchd
    exit 0
    ;;
  stop)
    shift
    stop_launchd
    exit 0
    ;;
```

Replace default/timed behavior with `start_launchd` calls:

```bash
if [[ $# -eq 0 ]]; then
  echo -e "${GREEN}☕️  已在后台保持清醒 (使用 'nosleep status' 查看)${NC}"
  start_launchd -d -u -i -s
  exit 0
fi

# timed modes
if [[ "${MODE}" == "system" ]]; then
  start_launchd -i -s -t "$SECONDS"
else
  start_launchd -d -u -i -s -t "$SECONDS"
fi
```

Update help text to mention default background, `status`, and `stop <id|pid>`.

**Step 3: Run test to verify it passes**

Run: `./tests/smoke.sh`
Expected: PASS with new help output and status/stop behavior.

**Step 4: Commit**

```bash
git add nosleep tests/smoke.sh
git commit -m "feat: add launchd status/stop and default background"
```

### Task 3: Update README usage for new commands

**Files:**
- Modify: `README.md`

**Step 1: Write the failing test**

Add a README assertion to `tests/smoke.sh`:

```bash
if ! grep -q "nosleep status" "$ROOT_DIR/README.md"; then
  fail "README missing status command"
fi
if ! grep -q "nosleep stop" "$ROOT_DIR/README.md"; then
  fail "README missing stop command"
fi
```

**Step 2: Run test to verify it fails**

Run: `./tests/smoke.sh`
Expected: FAIL with README missing status/stop commands.

**Step 3: Write minimal implementation**

Add usage examples in `README.md`:

```markdown
nosleep 2h
nosleep status
nosleep stop 1
```

**Step 4: Run test to verify it passes**

Run: `./tests/smoke.sh`
Expected: PASS

**Step 5: Commit**

```bash
git add README.md tests/smoke.sh
git commit -m "docs: add status/stop usage"
```
