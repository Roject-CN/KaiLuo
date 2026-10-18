extends Node2D
class_name Employee

@export var employee_name : String = "员工"
@export var speed := 80.0
@export var employee_state_manager : EmployeeStateManager
@export var label : Label

var spawn_place : Location
var work_place : Location

var _navigation_path: PackedVector2Array = PackedVector2Array()
var _navigating: bool = false
class Target : 
	var _target_position : Vector2
	var _has_target : bool = false
var target := Target.new()

signal navigation_over

func navigate(to : Vector2) -> void:
	if NaviService.is_walkable(NaviService.world_to_cell(to)):
		target._target_position = to
		target._has_target = true
		_navigating = true
	
func navigating_process(delta: float) -> void:
	if not target._has_target:
		_navigating = false
		return

	_navigation_path = NaviService.find_world_path(
		self.global_position, target._target_position
	)

	# 路径空 = 和目标同格。此时可能还没走到精确坐标
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
	var to_target := target._target_position - self.global_position
	var dist := to_target.length()

	if dist <= 1.0:
		# 真到了
		global_position = target._target_position
		_navigating = false
		target._has_target = false
		navigation_over.emit()
		return

	# 还没到：同格内直线靠近
	var step := speed * delta
	if dist <= step:
		global_position = target._target_position
	else:
		global_position += to_target / dist * step

func _ready() -> void:
	if not employee_state_manager:
		push_error("Employee: employee_state_manager 未设置")
		return

func init() -> void:
	# 延后到本帧末尾才进初始状态：调用方通常在自己的 _ready 里配置坐标和导航服务，
	# 立刻进状态的话，初始状态里的寻路会撞上还没配置好的服务
	_start_initial_state.call_deferred()
	label.text = self.employee_name

func _start_initial_state() -> void:
	employee_state_manager.start_state_manager()

func _physics_process(delta: float) -> void:
	if _navigating:
		navigating_process(delta)
	# 状态机每帧都要 tick：不然不移动的状态（待机、到达后的判定）永远不执行
	employee_state_manager._manager_process(delta)


## 当前是否还在沿路径移动（给状态脚本和调试面板用）
func is_navigating() -> bool:
	return _navigating

## 让外部（ChatService）能请求切换状态，而不认识 state_manager
func enter_state(s: EmployeeState.STATE) -> void:
	if employee_state_manager:
		employee_state_manager.transition(s)
