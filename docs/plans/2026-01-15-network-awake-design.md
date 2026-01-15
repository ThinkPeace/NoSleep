# NoSleep Network-Awake Behavior Design

**Goal:** 默认与定时模式下保证系统不休眠、网络不断；`bg` 模式允许黑屏但系统仍保持唤醒；`run` 模式在命令执行期间同样保证系统不休眠与网络不断。

**User Requirements:**
- `nosleep`（无参数）保持屏幕常亮，同时系统不休眠、网络不中断。
- `nosleep <time>`（定时）也必须系统不休眠、网络不中断。
- `nosleep bg <time>` 允许屏幕熄灭，但系统不休眠、网络不中断。
- 说明文档和帮助信息需明确“网络不中断/系统不休眠”。

**Proposed Behavior (caffeinate flags):**
- 默认：`caffeinate -d -u -i -s`
- 定时显示：`caffeinate -d -u -i -s -t <seconds>`
- `bg` 定时：`caffeinate -i -s -t <seconds>`
- `run` 模式：`caffeinate -d -i -s <command...>`

**Rationale:**
- `-i` 防止系统进入 idle sleep。
- `-s` 在插电时也防止 system sleep，提高网络与后台任务的稳定性。
- `-d -u` 保持屏幕亮并唤醒显示；`bg` 模式仅去掉 `-d`，允许黑屏省电。

**Trade-offs:**
- 电量消耗增加，尤其 `-s` 在插电时会更强制保持系统不睡眠。
- 但符合“网络持续可用”的核心需求。

**Docs Impact:**
- README 与 `--help` 文字需要强调：默认与定时模式会保持系统不休眠，确保网络持续；`bg` 允许黑屏但不休眠。
