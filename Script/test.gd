extends Node2D

@export var navigation_layer : TileMapLayer
@export var path_layer: TileMapLayer
@export var employee_manager : Node2D
@export var spawn_marker : Marker2D
@export var work_marker : Marker2D

func _ready() -> void:
	if not (navigation_layer and path_layer and employee_manager and spawn_marker and work_marker):
		assert(false, "@export is not all full in test.scene")
		return
	#astar grid的导航配置
	NaviService.set_up(navigation_layer, path_layer)

	# 员工在场景里摆好了，这里只把标记点坐标发给他们，初始状态用场景自带的
	for employee in _employees():
		employee.spawn_position = spawn_marker.global_position
		employee.work_position = work_marker.global_position
		employee.global_position = spawn_marker.global_position
		employee.init()

func _employees() -> Array[Employee]:
	var found: Array[Employee] = []
	if not employee_manager:
		return found
	for child in employee_manager.get_children():
		var employee := child as Employee
		if employee:
			found.append(employee)
	return found

func _physics_process(_delta: float) -> void:
	if not Input.is_action_just_pressed("left_mouse"):
		return
	for employee in _employees():
		var world_path := NaviService.find_world_path(employee.global_position, navigation_layer.get_local_mouse_position())
		employee.navigate(world_path)
