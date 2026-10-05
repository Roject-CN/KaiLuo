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
	current_state = initial_state
	current_state.state_enter()

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
