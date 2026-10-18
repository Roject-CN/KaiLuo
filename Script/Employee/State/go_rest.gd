extends EmployeeState

## 使用休息设施：找最近的 REST 点位 → 排队 → 走到等待位 → 轮到了就走过去用 5 秒 → 回工位。
## 5 秒目前只是占位，后续替换成真实的休息效果。

const STAY_TIME := 5.0

enum Phase { NONE, TO_WAIT, WAITING, TO_USE, USING }

var _location: Location = null
var _phase := Phase.NONE
var _timer := 0.0


func state_enter() -> void:
	_location = _find_rest()
	if _location == null:
		employee.enter_state(EmployeeState.STATE.GOWORK)
		return

	_location.queue_join(employee)
	employee.navigation_finished.connect(_on_navigation_finished)

	_timer = 0.0

	# 队首且设施空闲：直接去设施，不用先绕到等待位
	if _location.is_first(employee) and not _location.is_busy():
		if employee.navigate(_location.global_position):
			_phase = Phase.TO_USE
			return

	var wait_cell = NaviService.find_stand_cell(
		_location.global_position, 0, _wait_exclusions()
	)
	# find_stand_cell 返回的是格子坐标，导航要的是世界坐标
	if wait_cell == null or not employee.navigate(NaviService.cell_to_world(wait_cell)):
		# 没有等待位或者走不过去：原地排队，等轮到自己
		_phase = Phase.WAITING
		return
	_phase = Phase.TO_WAIT


func state_process(delta: float) -> void:
	if _location == null:
		return

	match _phase:
		Phase.WAITING:
			_try_start_use()
		Phase.USING:
			_timer += delta
			if _timer >= STAY_TIME:
				_location.end_use()
				_phase = Phase.NONE
				employee.enter_state(EmployeeState.STATE.GOWORK)


func state_exit() -> void:
	if employee.navigation_finished.is_connected(_on_navigation_finished):
		employee.navigation_finished.disconnect(_on_navigation_finished)

	if _location != null:
		if _phase == Phase.USING:
			_location.end_use()
		_location.queue_leave(employee)
		_location = null
	_phase = Phase.NONE


func _on_navigation_finished(result: Employee.Nav) -> void:
	match _phase:
		Phase.TO_WAIT:
			# 到了等待位；即使没走到（失败）也照样排队
			_phase = Phase.WAITING
		Phase.TO_USE:
			if result == Employee.Nav.ARRIVED:
				_location.begin_use(employee)
				_phase = Phase.USING
				_timer = 0.0
			else:
				_abort_back_to_work()


## 队首 + 设施空闲 → 走向设施
func _try_start_use() -> void:
	if _location.is_busy() or not _location.is_first(employee):
		return
	if not employee.navigate(_location.global_position):
		_abort_back_to_work()
		return
	_phase = Phase.TO_USE


func _abort_back_to_work() -> void:
	if _location != null:
		_location.queue_leave(employee)
		_location = null
	_phase = Phase.NONE
	employee.enter_state(EmployeeState.STATE.GOWORK)


func _find_rest() -> Location:
	var lm := get_tree().get_first_node_in_group("location_manager") as LocationManager
	if lm == null:
		push_error("GoRest: 找不到 LocationManager")
		return null
	return lm.find_nearest(Location.TYPE.REST_PLACE, employee.global_position)


## 其他排队者已经站住的格子，等待位要避开
func _wait_exclusions() -> Array:
	var cells: Array = []
	for other in _location.queue_members():
		if other == employee:
			continue
		cells.append(NaviService.world_to_cell(other.global_position))
	return cells
