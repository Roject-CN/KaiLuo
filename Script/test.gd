extends Node2D

@export var navigation_layer : TileMapLayer
@export var path_layer: TileMapLayer
@export var employee_manager : Node2D
@export var spawn_marker : Marker2D
@export var work_marker : Marker2D

var test_employee : Employee
const employee_scene_file := "res://Scene/Employee/employee.tscn"
const debug_panel_scene_file := "res://Scene/Debug/EmployeeStateDebugPanel.tscn"

func _ready() -> void:
	if not (navigation_layer and path_layer and employee_manager and spawn_marker and work_marker):
		assert(false, "@export is not all full in test.scene")
		return
	#astar grid的导航配置
	NaviService.set_up(navigation_layer, path_layer)

	test_employee = _spawn_employee("员工1")

	#调试面板：用来手动切换员工状态
	var panel := _spawn_debug_panel()
	if panel and test_employee:
		panel.track(test_employee)

func _spawn_employee(employee_name: String) -> Employee:
	var employee_scene := load(employee_scene_file) as PackedScene
	if not employee_scene:
		push_error("测试失败: 加载不到 %s" % employee_scene_file)
		return null
	var employee := employee_scene.instantiate() as Employee
	if not employee:
		push_error("测试失败: %s 的根节点不是 Employee" % employee_scene_file)
		return null
	employee.employee_name = employee_name
	employee.spawn_position = spawn_marker.global_position
	employee.work_position = work_marker.global_position
	employee.global_position = spawn_marker.global_position
	employee_manager.add_child(employee)
	return employee

func _spawn_debug_panel() -> EmployeeDebugPanel:
	var panel_scene := load(debug_panel_scene_file) as PackedScene
	if not panel_scene:
		push_error("测试失败: 加载不到 %s" % debug_panel_scene_file)
		return null
	var panel := panel_scene.instantiate() as EmployeeDebugPanel
	if not panel:
		push_error("测试失败: %s 的根节点不是 EmployeeDebugPanel" % debug_panel_scene_file)
		return null
	add_child(panel)
	return panel

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("left_mouse") and test_employee:
		var world_path := NaviService.find_world_path(test_employee.global_position, navigation_layer.get_local_mouse_position())
		test_employee.navigate(world_path)
