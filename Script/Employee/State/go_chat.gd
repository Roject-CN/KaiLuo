extends EmployeeState

var _session: ChatService.Session = null

func state_enter() -> void:
	_session = ChatService.request(employee)
	if _session == null:
		employee.enter_state(EmployeeState.STATE.WAITING)
		return
	employee.navigate(_session.meeting_point)

func state_process(_delta: float) -> void:
	if _session == null:
		return
	if employee.is_navigating():
		return
	# 先清掉 _session：这样接下来触发的 state_exit 不会误以为"还在路上"
	_session = null
	ChatService.notify_arrived(employee)

func state_exit() -> void:
	# 走到这里 _session 还非 null，说明是中途被打断
	if _session != null:
		ChatService.release(employee)
		_session = null
