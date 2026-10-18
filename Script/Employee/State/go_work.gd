extends EmployeeState

## 上班：走到自己被分配的工位，到达后把工位标记为「占用中」。
## 占用是工位「有人在岗」的唯一来源（聊天选搭档依赖它）。

var _arrived := false


func state_enter() -> void:
	_arrived = false
	if employee.work_place == null:
		push_error("GoWork: %s 没有分配工位" % employee.employee_name)
		return

	employee.navigation_finished.connect(_on_navigation_finished)
	if not employee.navigate(employee.work_place.return_global_position()):
		_disconnect_navigation()
		push_warning("GoWork: %s 无法到达工位" % employee.employee_name)


func _on_navigation_finished(result: Employee.Nav) -> void:
	if result != Employee.Nav.ARRIVED:
		return
	_arrived = true
	if employee.work_place != null:
		employee.work_place.begin_use(employee)


func state_exit() -> void:
	_disconnect_navigation()
	if _arrived and employee.work_place != null and employee.work_place.who_occupy == employee:
		employee.work_place.end_use()
	_arrived = false


func _disconnect_navigation() -> void:
	if employee.navigation_finished.is_connected(_on_navigation_finished):
		employee.navigation_finished.disconnect(_on_navigation_finished)
