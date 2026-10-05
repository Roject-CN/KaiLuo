extends Node2D

@export var navigation_layer : TileMapLayer
@export var path_layer: TileMapLayer
@export var employee_manager : Node2D
@export var spawn_marker : Marker2D
@export var work_marker : Marker2D

var test_employee : Employee
const employee_scene_file := "res://Scene/Employee/employee.tscn"

func _ready() -> void:	
	if not (navigation_layer and path_layer and spawn_marker and work_marker):
		assert(false, "@export is not all full in test.scene")
		return
	#astar grid的导航配置
	NaviService.set_up(navigation_layer, path_layer)
	
	#测试员工
	var employee_scene := load(employee_scene_file) as PackedScene
	var employee := employee_scene.instantiate() as Employee
	employee.spawn_position = spawn_marker.global_position
	employee.work_position = work_marker.global_position
	employee.global_position = spawn_marker.global_position
	employee_manager.add_child(employee)
	
	
func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("left_mouse") and test_employee:
		var world_path := NaviService.find_world_path(test_employee.global_position, navigation_layer.get_local_mouse_position())
		test_employee.navigate(world_path)
