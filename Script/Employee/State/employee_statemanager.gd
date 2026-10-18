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

## 切换可能发生在 state_exit 里（例如 GoChat.state_exit -> ChatService.release -> GOWORK）。
## 这里不允许嵌套执行：外层切换会把内层刚设好的 current_state 覆盖掉，
## 结果就是「current_state 说在等待，人却在走向工位」。
## 处理方式：切换进行中收到的请求先入队，等当前切换收尾后再依次执行。
const MAX_TRANSITION_HOPS := 8

var _transitioning := false
var _pending_state : EmployeeState = null

func transition(to_state: EmployeeState.STATE) -> void:
	var next := _states_by_name.get(to_state, null) as EmployeeState
	if next == null:
		push_error("EmployeeStateManager: 未注册状态 %s" % to_state)
		return
	if next == current_state:
		return

	if _transitioning:
		_pending_state = next
		return

	_run_transition(next)

	# 排队请求可能继续触发新的请求，循环消化；超过上限说明状态在互相触发，直接停手。
	var hops := 0
	while _pending_state != null:
		var queued := _pending_state
		_pending_state = null
		if queued == current_state:
			continue
		hops += 1
		if hops > MAX_TRANSITION_HOPS:
			push_error("EmployeeStateManager: 连续切换超过 %d 次，疑似状态互相触发，已停止" % MAX_TRANSITION_HOPS)
			break
		_run_transition(queued)


func _run_transition(next: EmployeeState) -> void:
	_transitioning = true
	if current_state:
		current_state.state_exit()
	current_state = next
	current_state.state_enter()
	_transitioning = false

## 当前状态（供调试面板之类的外部查询）
func get_current_state() -> EmployeeState:
	return current_state
