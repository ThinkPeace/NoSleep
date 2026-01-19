# NoSleep Status Remaining Time Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update `nosleep status` to show remaining time (HH:MM:SS or ∞), remove external process listing, and drop the timed-finish message.

**Architecture:** Keep logic inside the `nosleep` bash script. `status` reads launchd pid, then uses `ps` to parse caffeinate args and elapsed time, computing remaining time without extra state files.

**Tech Stack:** Bash, macOS `launchctl`, `ps`.

### Task 1: Update smoke tests for new status output

**Files:**
- Modify: `tests/smoke.sh`

**Step 1: Write the failing test**

Edit `tests/smoke.sh` to add new status expectations and stubs:

```bash
# Replace the old pmset stub and external-assertion checks with:
status_output_no_job="$(PATH=\"$stub_dir:$PATH\" \"$NOSLEEP\" status | strip_ansi)"
if ! echo "$status_output_no_job" | grep -q "当前没有"; then
  fail "status output missing 'no job' message"
fi
if echo "$status_output_no_job" | grep -q "外部阻止休眠"; then
  fail "status output should not include external assertions"
fi

# Add a new stub_dir_running with launchctl/ps stubs for running timed mode
status_output_running="$(PATH=\"$stub_dir_running:$PATH\" \"$NOSLEEP\" status | strip_ansi)"
if ! echo "$status_output_running" | grep -q "✅ nosleep 正在运行"; then
  fail "status output missing running message"
fi
if ! echo "$status_output_running" | grep -q "剩余时间: 00:00:25"; then
  fail "status output missing remaining time"
fi

# Add a new stub_dir_infinite with args lacking -t
status_output_infinite="$(PATH=\"$stub_dir_infinite:$PATH\" \"$NOSLEEP\" status | strip_ansi)"
if ! echo "$status_output_infinite" | grep -q "剩余时间: ∞"; then
  fail "status output missing infinite remaining time"
fi
```

Stub examples for running mode:

```bash
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
```

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL with missing remaining time or unexpected external assertions.

### Task 2: Implement remaining time parsing in status

**Files:**
- Modify: `nosleep`

**Step 1: Write the failing test**

Already covered in Task 1 (status expectations fail).

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL because `nosleep` does not output remaining time and still prints external assertions.

**Step 3: Write minimal implementation**

Update `status_launchd()` to:
- Remove the external process section.
- Add helpers to parse `ps -o etime=` to seconds and format remaining seconds as `HH:MM:SS`.
- Parse `-t` from caffeinate args to compute remaining time; show `∞` when missing.

Pseudo-code:

```bash
parse_etime_seconds() { ... }
format_hhmmss() { ... }

local args
args="$(ps -p "$pid" -o args=)"
local total
if [[ "$args" =~ -t[[:space:]]+([0-9]+) ]]; then
  total="${BASH_REMATCH[1]}"
fi
local elapsed
elapsed="$(ps -p "$pid" -o etime=)"
local elapsed_seconds
elapsed_seconds="$(parse_etime_seconds "$elapsed")"

if [[ -n "$total" ]]; then
  remaining=$((total - elapsed_seconds))
  if [[ $remaining -lt 0 ]]; then remaining=0; fi
  remaining_text="$(format_hhmmss "$remaining")"
else
  remaining_text="∞"
fi

echo "剩余时间: $remaining_text"
```

**Step 4: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS.

**Step 5: Commit**

```bash
git add tests/smoke.sh nosleep
git commit -m "feat: show remaining time in status"
```

### Task 3: Remove timed-finish message

**Files:**
- Modify: `nosleep`

**Step 1: Write the failing test**

Add a smoke test that runs `nosleep 1s` with `HOME` redirected to a temp dir and `launchctl` stubbed to avoid system changes, then assert output does NOT contain “时间到”.

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL because the message still prints.

**Step 3: Write minimal implementation**

Remove the final block that prints:

```bash
if [[ $? -eq 0 ]]; then
  echo -e "${CYAN}😴 时间到，恢复正常休眠策略。${NC}"
fi
```

**Step 4: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS.

**Step 5: Commit**

```bash
git add tests/smoke.sh nosleep
git commit -m "feat: remove timed finish message"
```
