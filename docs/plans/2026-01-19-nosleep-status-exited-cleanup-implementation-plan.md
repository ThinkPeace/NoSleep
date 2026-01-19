# NoSleep Status Exited Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Treat launchd jobs that have exited (no pid / not running) as stopped in `nosleep status`, and auto-clean them.

**Architecture:** Keep logic in `status_launchd()` within the `nosleep` script. Parse `launchctl print` output to detect exited state and missing pid, then bootout + remove the plist, returning the standard “no running task” message.

**Tech Stack:** Bash, macOS `launchctl`.

### Task 1: Add smoke test for exited job cleanup

**Files:**
- Modify: `tests/smoke.sh`

**Step 1: Write the failing test**

Add a stubbed `launchctl print` that returns `state = not running` and no pid, and verify:
- `nosleep status` prints “当前没有运行中的 nosleep 任务”。
- plist under a stubbed HOME is removed.

Example snippet:

```bash
stub_dir_exited="$(mktemp -d)"
stub_home_exited="$(mktemp -d)"
mkdir -p "$stub_home_exited/Library/LaunchAgents"
exited_plist="$stub_home_exited/Library/LaunchAgents/com.thinkpeace.nosleep.plist"
: > "$exited_plist"

cat >"$stub_dir_exited/launchctl" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "print" ]]; then
  cat <<'OUT'
state = not running
job state = exited
last exit code = 0
OUT
  exit 0
fi
exit 0
STUB
chmod +x "$stub_dir_exited/launchctl"

status_output_exited="$(HOME="$stub_home_exited" PATH="$stub_dir_exited:$PATH" "$NOSLEEP" status | strip_ansi)"
if ! echo "$status_output_exited" | grep -q "当前没有运行中的 nosleep 任务"; then
  fail "status output missing exited cleanup message"
fi
if [[ -f "$exited_plist" ]]; then
  fail "exited plist should be removed"
fi
```

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL (status currently reports running and leaves plist).

### Task 2: Implement exited cleanup in status

**Files:**
- Modify: `nosleep`

**Step 1: Write the failing test**

Covered by Task 1.

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL (exited job treated as running).

**Step 3: Write minimal implementation**

In `status_launchd()`:
- Parse `state` and `pid` from `launchctl print` output.
- If `state` is not `running` or `pid` is empty, run `launchd_bootout`, remove `LAUNCHD_PLIST`, and print the “当前没有运行中的 nosleep 任务” message, then return.

Pseudo-code:

```bash
info="$(launchctl print ...)"
state="$(echo "$info" | awk -F' = ' '/^[[:space:]]*state =/{print $2; exit}')"
pid="$(echo "$info" | awk -F' = ' '/pid =/{print $2; exit}')"
if [[ -z "$pid" || "$state" != "running" ]]; then
  launchd_bootout
  rm -f "$LAUNCHD_PLIST"
  echo -e "${YELLOW}ℹ️  当前没有运行中的 nosleep 任务。${NC}"
  return 0
fi
```

**Step 4: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS.

**Step 5: Commit**

```bash
git add tests/smoke.sh nosleep
git commit -m "fix: clean exited launchd job in status"
```
