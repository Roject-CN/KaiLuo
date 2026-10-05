extends Node2D
class_name Employee

@export var employee_name : String = "员工"
@export var speed := 80.0
@export var employee_state_manager : EmployeeStateManager

var spawn_position : Vector2
var work_position : Vector2

var path_index: int = 0
var navigation_path: PackedVector2Array = PackedVector2Array()
var navigating: bool = false

func navigate(path: PackedVector2Array) -> void:
	navigation_path = path
	path_index = 0
	navigating = not path.is_empty()
	
func navigating_process(delta: float) -> void:
	# 已经到最后一个点
	if path_index >= navigation_path.size():
		navigating = false
		return

	var next_point := navigation_path[path_index]
	var to_next := next_point - global_position
	var dist := to_next.length()
	var step := speed * delta

	if dist <= step:
		# 这一帧能到达，直接吸附，避免过冲
		global_position = next_point
		path_index += 1
	else:
		# 朝目标方向走固定距离
		global_position += to_next / dist * step

func _ready() -> void:
	if not employee_state_manager:
		push_error("Employee: employee_state_manager 未设置")
		return
	employee_state_manager.start_state_manager()

func _physics_process(delta: float) -> void:
	if not navigating:
		return
	navigating_process(delta)
	employee_state_manager._physics_process(delta)
