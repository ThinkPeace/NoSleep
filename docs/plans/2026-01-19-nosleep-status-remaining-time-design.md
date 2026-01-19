# NoSleep Status Remaining-Time & Output Simplification Design

**Goal:**
- `nosleep status` 不再显示“外部阻止休眠的进程”段落。
- `nosleep status` 始终显示“剩余时间”，定时显示 `HH:MM:SS`，非定时显示 `∞`。
- 定时结束后不再输出“😴 时间到，恢复正常休眠策略”。

**Scope:**
- 仅改动 `nosleep` 脚本的状态输出与结束提示；不引入额外状态文件。

**Proposed Behavior:**
- `status` 先用 `launchctl print gui/$UID/$LAUNCHD_LABEL` 判断任务是否存在；不存在则输出“当前没有运行中的 nosleep 任务”。
- 存在时解析 pid，并用 `ps -p <pid> -o args=` 解析 caffeinate 参数。
  - 若包含 `-t <seconds>`，则总时长为该秒数。
  - 否则视为非定时，剩余时间显示 `∞`。
- 用 `ps -p <pid> -o etime=` 获取已运行时间并解析为秒数；剩余时间 = 总时长 - 已运行秒数；小于 0 则显示 `00:00:00`。
- 若 `etime` 或 `-t` 解析失败，剩余时间显示 `未知`，但状态仍可展示。

**Parsing Details:**
- `etime` 支持 `mm:ss`、`hh:mm:ss`、`dd-hh:mm:ss`，统一换算为秒。
- `args` 仅针对 `-t` 后的数字解析，忽略其他标记。

**Output Changes:**
- 移除 `status` 中“外部阻止休眠的进程”标题与列表。
- 移除定时结束的提示文案。

**Error Handling:**
- `launchctl print` 不存在或 `ps` 返回空：视为未运行。
- `pid` 缺失：视为未运行并提示。

**Testing (Manual):**
- `nosleep 10s` 后立刻 `nosleep status`，确认显示剩余时间为 `00:00:0X`。
- `nosleep`（无参数）后 `nosleep status`，剩余时间显示 `∞`。
- `nosleep bg 10s` 后 `nosleep status`，剩余时间按倒计时显示。
- 定时结束后无“时间到”提示。
