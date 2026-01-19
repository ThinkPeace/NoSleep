# NoSleep Etime Octal Parsing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent `nosleep status` from failing when `ps etime` includes leading zeros (e.g., `00:08`).

**Architecture:** Update `parse_etime_seconds()` to force decimal arithmetic using `10#` so values like `08`/`09` are parsed as base-10.

**Tech Stack:** Bash.

### Task 1: Add smoke test for leading-zero etime

**Files:**
- Modify: `tests/smoke.sh`

**Step 1: Write the failing test**

Extend the running stub to return an `etime` with leading zero seconds so current arithmetic fails.

```bash
cat >"$stub_dir_running/ps" <<'STUB'
#!/usr/bin/env bash
if [[ "$*" == *"-o args="* ]]; then
  echo "/usr/bin/caffeinate -d -u -i -s -t 30"
  exit 0
fi
if [[ "$*" == *"-o etime="* ]]; then
  echo "00:08"
  exit 0
fi
exit 0
STUB
```

Then assert the remaining time renders normally (e.g., `00:00:22`).

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL with “value too great for base”.

### Task 2: Fix decimal parsing in `parse_etime_seconds`

**Files:**
- Modify: `nosleep`

**Step 1: Write the failing test**

Covered by Task 1.

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL.

**Step 3: Write minimal implementation**

Change the arithmetic expression to force decimal parsing:

```bash
echo $((10#$days * 86400 + 10#$hours * 3600 + 10#$mins * 60 + 10#$secs))
```

**Step 4: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS.

**Step 5: Commit**

```bash
git add tests/smoke.sh nosleep
git commit -m "fix: parse etime as decimal"
```
