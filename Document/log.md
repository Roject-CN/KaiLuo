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

## 2026-10-18 名字标签下沉 + 头顶对话气泡

### 1. 员工场景（employee.tscn / employee.gd）
- `Label` 改名 `NameLabel`，从头顶移到脚底（offset 2~14）；导出 `label` 改名 `name_label`。
- 新增 `ChatLabel`（默认隐藏，位于头顶上方 -54~-30），导出 `chat_label`。
- Employee 新增两个 API：`show_chat_line(text)` / `hide_chat_line()`。

### 2. 台词显示改到说话人头上（chat_service.gd）
- 约定「偶数下标 = 发起方 a，奇数下标 = 对方 b」，每句交给说话人自己的气泡。
- 计时到点先收气泡，再推进下一句，因此下一句自然出现在另一个员工头上。
- 会话结束/被打断时兜底清掉双方气泡。
- 删除 test.tscn 的临时 `speaking_label` 节点，以及 ChatService 里按 group 查找 Label 的逻辑。

### 3. 顺带保留
- test.tscn 的 `EmployeeManager` 保持 `y_sort_enabled = true`（按方案 A 的修复）。

### 验证
- `godot --headless --quit-after 240`：exit 0，无解析/运行错误。
- 未验证：聊天链路仍没有触发器，气泡效果需要手动切到 GOCHAT 或接入时间系统后观察。

## 2026-10-18 ChatService 重构：脚本 Autoload → 场景 Autoload + 4 个子节点

### 结构
- `Scene/Autoload/ChatService.tscn`
  - `PartnerFinder`  找搭档 + 会合点（LocationManager / NaviService）
  - `SessionBook`    会话登记与占用表
  - `DialogueRunner` 台词推进与计时（只发信号）
  - `ChatPresenter`  把台词写到员工头顶气泡（只订阅信号）
- 根节点 `Script/Autoload/chat_service.gd` 只保留对外 API + 依赖注入 + 信号接线。
- `ChatSession`（`Script/Autoload/ChatService/chat_session.gd`）只存数据；`Session` 类型引用全部改为 `ChatSession`。

### 工程配置
- `project.godot`：`ChatService` 由脚本 uid 改为场景路径 `*res://Scene/Autoload/ChatService.tscn`。

### 验证（无头集成测试，临时探针已删除）
- 两名员工走到工位并被 Location 占用 → 触发 GOCHAT → 走到会合点 → 进入 CHATTING。
- 台词按「偶数下标 a / 奇数下标 b」交替出现在各自头顶气泡：
  - T1.6 a=「今天天气不错啊。」
  - T2.8 b=「是啊，适合出去走走。」
  - T4.0 a=「不过还有活没干完。」
  - T5.6 b=「唉，别提了。」
- 每句到时消失、下一句换人；T6.4 会话结束，双方回 GoWork，气泡清空。

## 2026-10-18 chat_service.gd 移入 ChatService 目录 + 会合点改为按最小距离选格

### 1. 文件位置
- `Script/Autoload/chat_service.gd` → `Script/Autoload/ChatService/chat_service.gd`（含 .uid，用 git mv 保留历史）。
- `Scene/Autoload/ChatService.tscn` 的 ext_resource 路径同步更新。

### 2. 会合点：从「对方格子的邻居」改为「满足最小距离的邻居格」
- 原因：原实现只取 8 个邻居里第一个可走的格子。对方站在工位标记上（不在格子中心），
  相邻格中心实测只离 11px；而精灵是 16×16 缩放到 1.5 倍 = 24px 宽，于是看起来是叠在一起。
- `NaviService.find_stand_cell(target, min_distance)`：先在相邻一圈里找，距离不够再退到外圈；
  同一圈取「满足 min_distance 的最近一格」，保证两个人停在不同的格子、且不会贴脸。
- `PartnerFinder.min_stand_distance`（导出，默认 16 = 一格）：想让两人更开，把它调成 24/32 即可，不用改代码。

### 验证
- 无头实测：会合点距离从 11.0px 提升到 18.6px（a 在 (216,248)，b 在 (231,237)，格 (13,15) vs (14,14)）。
- 聊天流程本身不受影响：仍能进入 CHATTING 并按台词交替显示。

## 2026-10-18 会合点选格回退 + 间距加大

### 回退
- `NaviService.find_stand_cell` 恢复原来的 `_STAND_OFFSETS` 固定顺序（下 → 右 → 上 → 左 → 四个斜角），
  取第一个可走格；之前那套「按最小距离在环上搜索」的写法已删除。

### 加大间距
- 新增可选参数 `extra_cells`：沿选中的方向再往外推几格；外圈格不可走时退回原来那一格。
- `PartnerFinder.extra_stand_cells`（导出，默认 1）：0 = 紧挨着（原行为），1 = 隔一格，2 = 隔两格。

### 实测
- 会合点 (232,264)，对方 (231,237)，距离 27.0px，格 (14,16) vs (14,14)。
- 对比：回退前默认是 11.0px（叠在一起），上一版环搜索是 18.6px。

## 2026-10-18 整理：提交未提交的文档与场景改动

- `Project.md`：补充项目定位、目录结构与工作方式（先方案后改码、改完 commit + 写 log）。
- `Scene/Autoload/ChatService.tscn`：编辑器保存时补齐了场景与脚本的 uid、节点的 unique_id，内容无变化。
- `Scene/Employee/employee.tscn`：`ChatLabel` 调整了尺寸/位置与垂直对齐（-67~67 / -46~-22，vertical_alignment = 2）；
  其中 `text = "xxx"` 仍是调试占位文字，等下一次改动时清空。

## 2026-10-18 文档修正

- `Project.md`：「得到拥护同意」→「得到用户同意」，并补上文件末尾换行。

## 2026-10-18 占用改为状态显式设置；新增排队 API

### 1. Location：删掉 Area2D 自动占用，改为显式 API
- 删：`_area` / `_candidates` / `_stay_timer` / `_first_candidate` / `occupy_delay` / `area_radius` /
  `_physics_process` 里的自动占用、`occupy()` / `release()`。
- 新增：`begin_use(employee)` / `end_use()` / `is_busy()`，以及 `freed` 信号。占用只有状态机一个真相源。
- 新增队列：`queue_join` / `queue_leave` / `is_first` / `queue_index` / `queue_members`（先来先服务）。

### 2. GoWork：到达占用、离开释放
- 到达工位时 `work_place.begin_use(self)`，`state_exit` 时释放。
- 聊天选搭档仍然读 `who_occupy`，现在拿到的就是「真的站在工位上的人」，不再有 1 秒延迟和 12px 半径误差。

### 3. 配套
- `LocationManager.find_nearest(type, from)`：不跳过被占用的点位（排队需要）。
- `NaviService.find_stand_cell()` 增加 `exclude` 参数：排队选等待位时可以避开别人已占的格子。

### 验证
- 无头启动无错误；12 秒后两个工位分别被员工1/员工2占用，`find_partner(null)` 能正常找到搭档。

## 2026-10-18 新增 USE_REST / REPORT 两个状态

### 实现
- `EmployeeState.STATE` 追加 `USE_REST`(5)、`REPORT`(6)，已有状态值不变。
- `use_rest.gd`：找最近的 REST 点位 → 排队 → 走到等待位 → 队首且空闲时走向设施 → 到达后占用 5 秒 → 回 GoWork。
  等待位用 `NaviService.find_stand_cell(..., exclude)` 选，避开其他排队者已站的格子。
- `report.gd`：找最近的 BOSS 点位 → 导航 → 到达后占用 5 秒 → 回 GoWork。
- 两个状态都是独立脚本，不共基类；`STAY_TIME = 5.0` 目前只是占位，后续替换为真实效果。
- `test.tscn` 摆放 `Rest1`（type=2, 408,424）、`Boss1`（type=3, 264,168），均在可走格上。
- 调试面板 `state_labels` 增加「休息」「汇报」。

### 验证（无头探针，临时文件已删）
- 使用设施：员工1 于 T4.0 开始占用，T9.0 释放并回 GoWork（正好 5 秒）。
- 排队递补：员工2 先站在旁边等待，员工1 释放后 T9.5 接手占用，队列顺序正确。
- 汇报：员工1 到达 BOSS 点位后占用 5 秒，随后自动回 GoWork。

## 2026-10-18 状态改名 GoRest / GoReport；调试面板按白名单显示并自适应列宽

### 1. 状态改名
- `USE_REST` → `GO_REST`（节点 `GoRest`，脚本 `go_rest.gd`）
- `REPORT` → `GO_REPORT`（节点 `GoReport`，脚本 `go_report.gd`）
- `state_name` 数值保持 5 / 6，场景引用不用改。

### 2. 调试面板
- `state_labels` 改成白名单：只有列在里面的状态才生成列。现在显示 上班 / 下班 / 去聊天 / 休息 / 汇报，
  中间状态（等待 / 聊天中）不再出现在面板上。
- 列宽不再写死：`_apply_layout_metrics()` 按当前视口宽度实时计算——名字列刚好容纳 4 个汉字，
  剩余宽度平分给各状态列；视口尺寸变化时自动重建。
- 删除场景里 176px 的固定最小宽度占用（运行时按计算结果覆盖）。

### 验证（无头探针，临时文件已删）
- 视口宽 720，面板实际宽 676（不溢出）。
- 表头 6 格：员工(76) + 上班/下班/去聊天/休息/汇报(各 114)。
- 每行 5 个按钮，宽度 114。

## 2026-10-18 修复：排队的人没有走到等待位

### 原因
- `NaviService.find_stand_cell()` 返回的是**格子坐标 Vector2i**，但 `Employee.navigate()` 要的是**世界坐标**。
- 直接把格子传给 navigate，会被当成世界坐标（如 (25,27)），落在导航区域外 → `navigate()` 返回 false，
  代码走「原地排队」分支，于是人留在工位上等。

### 修复
- `employee.navigate(NaviService.cell_to_world(wait_cell))`，先把格子转成世界坐标。
- 补一条捷径：进入状态时如果自己就是队首且设施空闲，直接导航到设施，不用先绕到等待位。

### 验证（无头探针，临时文件已删）
- 员工1 先去使用；员工2 在 T2 走到 (264,168)（离设施 19.1px）的等待位站定，一直等到 T7。
- T8 员工1 结束并回工位；T9 员工2 接手占用，使用 5 秒；T14 回工位。
