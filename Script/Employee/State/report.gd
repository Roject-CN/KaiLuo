extends EmployeeState

## 向老板汇报：找到 BOSS 点位 → 走过去 → 停留 5 秒 → 回工位。
## 5 秒目前只是占位，后续替换成真实的汇报效果。

const STAY_TIME := 5.0

var _location: Location = null
var _arrived := false
var _timer := 0.0


func state_enter() -> void:
	_arrived = false
	_timer = 0.0
	_location = _find_boss()
	if _location == null:
		employee.enter_state(EmployeeState.STATE.GOWORK)
		return

	employee.navigation_finished.connect(_on_navigation_finished)
	if not employee.navigate(_location.global_position):
		_disconnect_navigation()
		_abort_back_to_work()


func state_process(delta: float) -> void:
	if not _arrived:
		return
	_timer += delta
	if _timer >= STAY_TIME:
		employee.enter_state(EmployeeState.STATE.GOWORK)


func state_exit() -> void:
	_disconnect_navigation()
	if _location != null and _location.who_occupy == employee:
		_location.end_use()
	_location = null
	_arrived = false


func _on_navigation_finished(result: Employee.Nav) -> void:
	if result != Employee.Nav.ARRIVED:
		return
	_arrived = true
	_timer = 0.0
	# 老板点位已经有人时不抢占用（先到先得）
	if _location != null and not _location.is_busy():
		_location.begin_use(employee)


func _abort_back_to_work() -> void:
	_location = null
	_arrived = false
	employee.enter_state(EmployeeState.STATE.GOWORK)


func _disconnect_navigation() -> void:
	if employee.navigation_finished.is_connected(_on_navigation_finished):
		employee.navigation_finished.disconnect(_on_navigation_finished)


func _find_boss() -> Location:
	var lm := get_tree().get_first_node_in_group("location_manager") as LocationManager
	if lm == null:
		push_error("Report: 找不到 LocationManager")
		return null
	return lm.find_nearest(Location.TYPE.BOSS_PLACE, employee.global_position)
