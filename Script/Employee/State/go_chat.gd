extends EmployeeState

var _session: ChatService.Session = null

func state_enter() -> void:
	_session = ChatService.request(employee)
	if _session == null:
		employee.enter_state(EmployeeState.STATE.WAITING)
		return

	# 先发起导航，再连信号：navigate 返回 false 时不会再发信号，失败分支必须自己处理。
	if not employee.navigate(_session.meeting_point):
		_abort_chat()
		return
	employee.navigation_finished.connect(_on_navigation_finished)

func state_process(_delta: float) -> void:
	pass

func state_exit() -> void:
	if employee.navigation_finished.is_connected(_on_navigation_finished):
		employee.navigation_finished.disconnect(_on_navigation_finished)
	# 走到这里 _session 还非 null，说明是中途被打断（不是正常抵达）
	if _session != null:
		ChatService.release(employee)
		_session = null

## 导航有结果了才决定下一步；不再用 is_navigating() 轮询
func _on_navigation_finished(result: Employee.Nav) -> void:
	if _session == null:
		return
	if result != Employee.Nav.ARRIVED:
		_abort_chat()
		return
	# 先清掉 _session：接下来触发的 state_exit 不会误以为「还在路上」
	_session = null
	ChatService.notify_arrived(employee)

## 到不了：把会话还给 ChatService，然后回到待机
func _abort_chat() -> void:
	var session := _session
	_session = null
	if session != null:
		ChatService.release(employee)
	employee.enter_state(EmployeeState.STATE.WAITING)
