# 修改日志

## 2026-10-18 员工状态机切换门 + 导航结果 API

### 1. EmployeeStateManager.transition：禁止嵌套切换
- 问题：`state_exit()` 里再次调用 `transition()`（GoChat.state_exit → ChatService.release → GOWORK）时，
  外层切换收尾会把内层刚设好的 `current_state` 覆盖掉，出现「current_state = WAITING，人却在走向工位」。
- 改法：新增 `_transitioning` 门 + `_pending_state` 队列。切换进行中收到的请求只入队，
  当前切换收尾后再依次执行；最多连续 8 次，超过则 `push_error` 并停手（防状态互相触发）。
- 效果：`current_state` 与实际行为不再脱钩；`state_exit` 每个状态每次切换只执行一次。

### 2. Employee 导航：从「标志位」改成「有结果的动作」
- 新增 `enum Nav { IDLE, MOVING, ARRIVED, FAILED }` 与 `signal navigation_finished(result: Nav)`，
  取代原来的 `navigation_over`（无参数、且只在成功时发）。
- `navigate()` 改为返回 `bool`：目标格不可走、或 A* 无路时返回 false，
  同时清空旧目标（不再继续走向上一个目标）并发出 `FAILED`。
- `_finish_navigation()` 区分「空路径 = 同格」与「空路径 = 不可达」：不同格直接判失败，杜绝直线穿墙。
- `NaviService.has_path()`：只判定可达、不画调试路径，供导航发起前预检。

### 3. GoChat：改为事件驱动
- 不再用 `is_navigating()` 轮询「到了没有」，改为等待 `navigation_finished`。
- 发起导航失败 → 归还会话并回 WAITING；途中失败/被打断 → 同样归还。
- `state_exit` 里断开信号，避免残留回调。

### 验证
- `godot --headless --path . --quit-after 240`：退出码 0，无 SCRIPT ERROR / Parse Error。
- 覆盖：脚本编译、场景加载、员工从出生点走到工位（真实跑了 240 帧）。
- 未覆盖：聊天链路没有触发器（GOCHAT 目前只能由调试面板手动进入），需在接入时间系统或调试入口后再实测。
