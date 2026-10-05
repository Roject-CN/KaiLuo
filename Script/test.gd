extends Node2D

@export var navigation_layer : TileMapLayer
@export var path_layer: TileMapLayer
@export var employee_manager : Node2D
@export var spawn_marker : Marker2D
@export var work_marker : Marker2D
## 在编辑器里把 DebugPanel 拖进来即可（实例节点的导出没法手写进 .tscn）
@export var debug_panel : EmployeeDebugPanel

## 每个员工想要的初始状态（状态子节点名）。
## 场景里所有员工都继承 employee.tscn 的 initial_state，想各自不同就在这个表里点名。
const INITIAL_STATES := {
	"员工1": "GoWork",
	"员工2": "OffWork",
}

func _ready() -> void:
	if not (navigation_layer and path_layer and employee_manager and spawn_marker and work_marker):
		assert(false, "@export is not all full in test.scene")
		return
	#astar grid的导航配置
	NaviService.set_up(navigation_layer, path_layer)

	# 员工在场景里摆好了，这里只把标记点坐标和各自想要的初始状态发给他们
	for employee in _employees():
		employee.spawn_position = spawn_marker.global_position
		employee.work_position = work_marker.global_position
		var want := INITIAL_STATES.get(employee.employee_name, "") as String
		if want != "":
			employee.employee_state_manager.set_initial_state(want)

	# 面板的 _ready 跑得比这里早，那时它拿不到员工，所以由这里把员工交给它
	if debug_panel:
		debug_panel.track_employees(employee_manager)
	else:
		push_warning("test.gd: debug_panel 没接上，左侧调试面板不会显示员工")

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
