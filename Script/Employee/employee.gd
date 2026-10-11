extends Node2D
class_name Employee

@export var employee_name : String = "员工"
@export var speed := 80.0
@export var employee_state_manager : EmployeeStateManager
@export var timer : Timer
@export var label : Label

var spawn_position : Vector2
var work_position : Vector2

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
	# 每一物理帧都在不断重新请求
	if not target._has_target:
		_navigating = false
		return
	_navigation_path = NaviService.find_world_path(
		self.global_position, target._target_position
	)
	
	#寻路完成之后
	if _navigation_path.size() == 0 :
		_navigating = false
		target._has_target = false
		navigation_over.emit()
		return
	
	#_navigation_path[0] 就是起点
	var next_point := _navigation_path[0]
	var to_next := next_point - self.global_position
	var dist := to_next.length()
	var step := speed * delta

	if dist <= step:
		# 这一帧能到达，直接吸附，避免过冲
		global_position = next_point
	else:
		# 朝目标方向走固定距离
		global_position += to_next / dist * step

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
	employee_state_manager._physics_process(delta)


## 当前是否还在沿路径移动（给状态脚本和调试面板用）
func is_navigating() -> bool:
	return _navigating
