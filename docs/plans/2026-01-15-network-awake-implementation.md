# Network-Awake Default Behavior Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update `nosleep` to keep the system awake (network available) in default and timed modes, while allowing `bg` to turn off the display but still prevent system sleep.

**Architecture:** Adjust `caffeinate` flags to include `-i -s` across modes, keep `-d -u` for display modes, and update help/README wording to reflect network/system awake behavior.

**Tech Stack:** Bash, macOS `caffeinate`.

---

### Task 1: Extend smoke test to require new help wording

**Files:**
- Modify: `tests/smoke.sh`

**Step 1: Write the failing test**

```bash
help_output="$($NOSLEEP --help | strip_ansi)"
if ! echo "$help_output" | grep -q "系统不休眠"; then
  fail "help output missing system awake wording"
fi
```

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL with "help output missing system awake wording"

**Step 3: Commit**

```bash
git add tests/smoke.sh
git commit -m "test: require system-awake wording in help"
```

---

### Task 2: Update `nosleep` caffeinate flags and help text

**Files:**
- Modify: `nosleep`

**Step 1: Write the failing test**

(Already added in Task 1)

**Step 2: Implement minimal changes**

Update help text to mention system awake + network, and update caffeinate calls:

```bash
# help text additions (example)
# "默认/定时模式会保持系统不休眠，网络不断。"

# no-arg default
caffeinate -d -u -i -s

# run mode
caffeinate -d -i -s "$@"

# display timed
caffeinate -d -u -i -s -t "$SECONDS"

# bg timed
caffeinate -i -s -t "$SECONDS"
```

**Step 3: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS with "OK"

**Step 4: Commit**

```bash
git add nosleep
git commit -m "feat: keep system awake for network in all modes"
```

---

### Task 3: Update README wording to match new behavior

**Files:**
- Modify: `README.md`

**Step 1: Write the failing test**

Add a README check to the smoke test:

```bash
if ! grep -q "系统不休眠" "$ROOT_DIR/README.md"; then
  fail "README missing system awake wording"
fi
```

**Step 2: Run test to verify it fails**

Run: `bash tests/smoke.sh`
Expected: FAIL with "README missing system awake wording"

**Step 3: Write minimal implementation**

Add a short sentence in Features or Usage describing:
- 默认/定时模式保持系统不休眠、网络不断
- bg 允许黑屏但系统不休眠

**Step 4: Run test to verify it passes**

Run: `bash tests/smoke.sh`
Expected: PASS with "OK"

**Step 5: Commit**

```bash
git add README.md tests/smoke.sh
git commit -m "docs: clarify system-awake behavior"
```

---

### Task 4: Verify

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

