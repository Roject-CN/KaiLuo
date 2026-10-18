extends Node
# chat_service.gd  —— Autoload 名 "ChatService"

# ---------------------------------------------------------------- 类型
class Session:
	var a: Employee
	var b: Employee
	var meeting_point: Vector2
	var phase: int = 0
	var dialogue: Array[String] = []
	var dialogue_index: int = -1     # -1 = 还没说第一句
	var line_timer: float = 0.0
	var speaker: Employee          # 当前正在说话的人（气泡挂在他头上）

# ---------------------------------------------------------------- 常量
const PHASE_MOVING := 0
const PHASE_CHATTING := 1

var res1 : = preload("res://Resource/test1.tres")
# ---------------------------------------------------------------- 配置
@export var seconds_per_char: float = 0.15
@export var min_line_duration: float = 1.0
@export var dialogue_pool: Array[ChatDialogue] = [res1]

# ---------------------------------------------------------------- 内部状态
var _location_manager: LocationManager
var _sessions: Array[Session] = []
var _busy: Dictionary = {}    # Employee -> Session

# ---------------------------------------------------------------- 信号
signal session_ended(a: Employee, b: Employee)

# ================================================================ 对外接口
## A 发起聊天请求，成功返回 session，失败返回 null
func request(from: Employee) -> Session:
	if _busy.has(from):
		return null

	var candidate := find_employee_at_workplace(from)
	if candidate == null:
		return null

	var stand_cell = NaviService.find_stand_cell(candidate.global_position)
	if stand_cell == null:
		return null

	var session := Session.new()
	session.a = from
	session.b = candidate
	session.meeting_point = NaviService.cell_to_world(stand_cell)
	session.phase = PHASE_MOVING

	_sessions.append(session)
	_busy[from] = session
	_busy[candidate] = session

	candidate.enter_state(EmployeeState.STATE.WAITING)
	return session


## A 到达会合点，双方进入聊天
func notify_arrived(employee: Employee) -> void:
	var session: Session = _busy.get(employee, null)
	if session == null:
		return
	if session.a != employee:
		return
	if session.phase != PHASE_MOVING:
		return
	_enter_chatting(session)


## 一方中途放弃（被打断）
func release(employee: Employee) -> void:
	var session: Session = _busy.get(employee, null)
	if session == null:
		return
	_end_session(session)


# ================================================================ 查询
func _get_location_manager() -> LocationManager:
	if not is_instance_valid(_location_manager):
		_location_manager = get_tree().get_first_node_in_group("location_manager") as LocationManager
	return _location_manager


## 从所有工位上正在占用的员工里随机挑一个（排除自己）
func find_employee_at_workplace(exclude: Employee = null) -> Employee:
	var lm := _get_location_manager()
	if lm == null:
		push_error("ChatService: 找不到 LocationManager")
		return null

	var candidates: Array[Employee] = []
	for loc in lm.get_by_type(Location.TYPE.WORK_PLACE):
		if loc.who_occupy and loc.who_occupy != exclude:
			candidates.append(loc.who_occupy)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


# ================================================================ 会话流程
func _enter_chatting(session: Session) -> void:
	session.phase = PHASE_CHATTING
	session.dialogue = _pick_dialogue()
	session.dialogue_index = -1
	session.line_timer = 0.0

	session.a.enter_state(EmployeeState.STATE.CHATTING)
	session.b.enter_state(EmployeeState.STATE.CHATTING)

	# 池子里没配台词：直接收尾，避免卡死
	if session.dialogue.is_empty():
		_end_session(session)


func _end_session(session: Session) -> void:
	_busy.erase(session.a)
	_busy.erase(session.b)
	_sessions.erase(session)

	# 兜底：打断时气泡可能还挂着
	_clear_line(session)
	session.a.hide_chat_line()
	session.b.hide_chat_line()

	session.a.enter_state(EmployeeState.STATE.GOWORK)
	session.b.enter_state(EmployeeState.STATE.GOWORK)
	session_ended.emit(session.a, session.b)


# ================================================================ 对话推进
func _physics_process(delta: float) -> void:
	for session in _sessions.duplicate():
		if session.phase != PHASE_CHATTING:
			continue
		_tick_dialogue(session, delta)


func _tick_dialogue(session: Session, delta: float) -> void:
	session.line_timer -= delta
	if session.line_timer > 0.0:
		return

	session.dialogue_index += 1

	# 这一句的时间到了：先收掉气泡，再决定有没有下一句
	_clear_line(session)

	# 台词说完了：结束整场会话
	if session.dialogue_index >= session.dialogue.size():
		_end_session(session)
		return

	_show_line(session)


## 当前这句由谁来说：约定偶数下标 = 发起方 a，奇数下标 = 对方 b
func _show_line(session: Session) -> void:
	var line := session.dialogue[session.dialogue_index]
	var speaker := session.a if session.dialogue_index % 2 == 0 else session.b

	# 换人说话：上一条已在计时结束时收掉，这里只做兜底
	if session.speaker != null and session.speaker != speaker:
		session.speaker.hide_chat_line()

	session.speaker = speaker
	speaker.show_chat_line(line)
	session.line_timer = max(min_line_duration, line.length() * seconds_per_char)


## 收掉当前这句话（推进到下一句、或整场结束时调用）
func _clear_line(session: Session) -> void:
	if session.speaker == null:
		return
	session.speaker.hide_chat_line()
	session.speaker = null


func _pick_dialogue() -> Array[String]:
	if dialogue_pool.is_empty():
		return []
	var d := dialogue_pool[randi() % dialogue_pool.size()]
	return d.lines.duplicate()
