extends Node
class_name EmployeeStateManager

## 状态切换完成后发出，方便调试面板之类的监听者刷新显示
signal state_changed(to_state: EmployeeState)

var states : Array[EmployeeState]
var current_state : EmployeeState
@export var employee : Employee
@export var initial_state : EmployeeState


func _ready() -> void:
	if not (employee and initial_state):
		push_error("EmployeeManager: employee 或 initial_state 未设置")
		return
	states.clear()
	for i in self.get_children():
		if i is EmployeeState:
			i.employee = employee
			states.append(i)
		

func start_state_manager() -> void:
	# 延后一帧再进入初始状态：员工是在场景 _ready 过程中入树的，
	# 这时导航之类的服务可能还没配置好，立刻寻路会撞上空引用
	_enter_initial_state.call_deferred()

func _enter_initial_state() -> void:
	current_state = initial_state
	if current_state:
		current_state.state_enter()
	state_changed.emit(current_state)

## 按状态子节点的名字设置初始状态，给每个员工配不同初始状态用
func set_initial_state(state_node_name: String) -> bool:
	if not state_node_name.is_empty():
		var node := get_node_or_null(NodePath(state_node_name))
		if node is EmployeeState:
			initial_state = node
			return true
	push_error("EmployeeStateManager: 找不到名为 %s 的状态子节点" % state_node_name)
	return false

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.state_process(delta)

func transition(to_state : EmployeeState) -> void:
	if not to_state:
		return
	if current_state:
		current_state.state_exit()
	current_state = to_state
	current_state.state_enter()
	state_changed.emit(current_state)

## 当前状态（供调试面板之类的外部查询）
func get_current_state() -> EmployeeState:
	return current_state
