extends Node2D
class_name Employee

## 一次导航的结果。调用方应当等 navigation_finished，不要用 is_navigating() 反推「到了没有」——
## 它分不清「从没开始」「正在走」「已经走完」。
enum Nav {
	IDLE,
	MOVING,
	ARRIVED,
	FAILED,
}

@export var employee_name : String = "员工"
@export var speed := 80.0
@export var employee_state_manager : EmployeeStateManager
@export var name_label : Label
@export var chat_label : Label

var spawn_place : Location
var work_place : Location

var _navigation_path: PackedVector2Array = PackedVector2Array()
var _navigating: bool = false
class Target : 
	var _target_position : Vector2
	var _has_target : bool = false
var target := Target.new()

## 一次导航结束（成功或失败）都会发；result 是 Nav.ARRIVED 或 Nav.FAILED
signal navigation_finished(result: Nav)

## 请求走向某个世界坐标。
## 返回 false 表示这次请求没有被接受：目标格不可走，或者从当前位置没有可达路径。
## 被拒绝时会清空旧目标（员工停在原地），并发出 navigation_finished(FAILED)。
func navigate(to : Vector2) -> bool:
	_clear_navigation()

	var to_cell := NaviService.world_to_cell(to)
	if not NaviService.is_walkable(to_cell):
		_fail_navigation()
		return false

	# 同格不用寻路；不同格必须先确认 A* 真能找到路。
	# 否则「路径为空」会同时表示「同格」和「无路可走」，员工就会直线穿墙。
	if to_cell != NaviService.world_to_cell(global_position) and not NaviService.has_path(global_position, to):
		_fail_navigation()
		return false

	target._target_position = to
	target._has_target = true
	_navigating = true
	return true

func navigating_process(delta: float) -> void:
	if not target._has_target:
		_navigating = false
		return

	_navigation_path = NaviService.find_world_path(
		self.global_position, target._target_position
	)

	# 路径空：navigate 已经排除了无路的情况，所以这里只可能是「和目标同格」。
	# 同格时补上最后一点精确距离。
	if _navigation_path.is_empty():
		_finish_navigation(delta)
		return

	# 沿路走一格
	var next_point := _navigation_path[0]
	var to_next := next_point - self.global_position
	var dist := to_next.length()
	var step := speed * delta

	if dist <= step:
		global_position = next_point
	else:
		global_position += to_next / dist * step


## 同格后的收尾：如果还没到精确坐标，直线走过去
func _finish_navigation(delta: float) -> void:
	# 理论上不会走到这里：navigate 已经保证可达。
	# 万一途中被判定为不可达，按失败处理，绝不允许直线穿墙。
	if NaviService.world_to_cell(global_position) != NaviService.world_to_cell(target._target_position):
		_fail_navigation()
		return

	var to_target := target._target_position - self.global_position
	var dist := to_target.length()

	if dist <= 1.0:
		# 真到了
		global_position = target._target_position
		_clear_navigation()
		navigation_finished.emit(Nav.ARRIVED)
		return

	# 还没到：同格内直线靠近
	var step := speed * delta
	if dist <= step:
		global_position = target._target_position
	else:
		global_position += to_target / dist * step


## 清空导航状态（只改状态，不动位置）
func _clear_navigation() -> void:
	_navigating = false
	target._has_target = false
	_navigation_path = PackedVector2Array()


## 导航失败：清空目标并广播，由调用方决定下一步
func _fail_navigation() -> void:
	_clear_navigation()
	navigation_finished.emit(Nav.FAILED)

func _ready() -> void:
	if not employee_state_manager:
		push_error("Employee: employee_state_manager 未设置")
		return

func init() -> void:
	# 延后到本帧末尾才进初始状态：调用方通常在自己的 _ready 里配置坐标和导航服务，
	# 立刻进状态的话，初始状态里的寻路会撞上还没配置好的服务
	_start_initial_state.call_deferred()
	if name_label:
		name_label.text = self.employee_name

func _start_initial_state() -> void:
	employee_state_manager.start_state_manager()

func _physics_process(delta: float) -> void:
	if _navigating:
		navigating_process(delta)
	# 状态机每帧都要 tick：不然不移动的状态（待机、到达后的判定）永远不执行
	employee_state_manager._manager_process(delta)


## 在头顶气泡里显示这句话（同一时刻只显示一句）
func show_chat_line(text: String) -> void:
	if chat_label == null:
		return
	chat_label.text = text
	chat_label.visible = true


## 收起头顶气泡
func hide_chat_line() -> void:
	if chat_label == null:
		return
	chat_label.text = ""
	chat_label.visible = false


## 当前是否还在沿路径移动（给状态脚本和调试面板用）
func is_navigating() -> bool:
	return _navigating

## 让外部（ChatService）能请求切换状态，而不认识 state_manager
func enter_state(s: EmployeeState.STATE) -> void:
	if employee_state_manager:
		employee_state_manager.transition(s)
