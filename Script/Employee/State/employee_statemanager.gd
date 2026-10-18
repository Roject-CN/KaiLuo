extends Node
class_name EmployeeStateManager

var current_state : EmployeeState
@export var employee : Employee
@export var initial_state : EmployeeState

# employee_statemanager.gd
var _states_by_name: Dictionary = {}

func _ready() -> void:
	if not (employee and initial_state):
		push_error("EmployeeManager: employee 或 initial_state 未设置")
		return
	_states_by_name.clear()
	for child in get_children():
		if child is EmployeeState:
			child.employee = employee
			_states_by_name[child.state_name] = child
		

func start_state_manager() -> void:
	current_state = initial_state
	if current_state:
		current_state.state_enter()


func _manager_process(delta: float) -> void:
	if current_state:
		current_state.state_process(delta)

func transition(to_state: EmployeeState.STATE) -> void:
	var next := _states_by_name.get(to_state, null) as EmployeeState
	if next == null:
		push_error("EmployeeStateManager: 未注册状态 %s" % to_state)
		return
	if next == current_state:
		return
	if current_state:
		current_state.state_exit()
	current_state = next
	current_state.state_enter()

## 当前状态（供调试面板之类的外部查询）
func get_current_state() -> EmployeeState:
	return current_state
