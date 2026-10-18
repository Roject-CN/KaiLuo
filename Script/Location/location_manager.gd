extends Node
class_name LocationManager

var locations: Array[Location] = []
var _by_type: Dictionary = {}   # TYPE -> Array[Location]
# employee_id -> Location
var _work_assignment: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is Location:
			locations.append(child)

	for loc in locations:
		_add_to_type(loc)

	add_to_group("location_manager")

func _add_to_type(loc: Location) -> void:
	if loc.type == Location.TYPE.NULL:
		return

	if not _by_type.has(loc.type):
		var arr: Array[Location] = []
		_by_type[loc.type] = arr

	var list: Array = _by_type[loc.type]
	list.append(loc)


## 按类型拿所有 Location
func get_by_type(type: Location.TYPE) -> Array:
	return _by_type.get(type, [])


## 按类型找“最近有空位”的
func find_available(type: Location.TYPE, from_world: Vector2) -> Location:
	var best: Location = null
	var best_dist := INF
		
	for loc : Location in get_by_type(type):
		if loc.is_busy():
			continue
		var d := from_world.distance_squared_to(loc.global_position)
		if d < best_dist:
			best_dist = d
			best = loc
	return best



## 找最近的同类点位。不跳过「已被占用」的点位——排队的前提就是占着也能过去。
func find_nearest(type: Location.TYPE, from_world: Vector2) -> Location:
	var best: Location = null
	var best_distance := INF
	for loc in get_by_type(type):
		var distance := from_world.distance_squared_to(loc.global_position)
		if distance < best_distance:
			best_distance = distance
			best = loc
	return best


## 出生点：直接查 SPAWN_PLACE 类型的第一个
func assign_spawn_location() -> Location:
	var spawns := get_by_type(Location.TYPE.SPAWN_PLACE)
	if spawns.is_empty():
		push_error("LocationManager: 没有 SPAWN_PLACE 类型的 Location")
		return null
	return spawns[0] 

func assign_work_location(employee_id: String) -> Location:
	# 已经分配过，直接复用
	if _work_assignment.has(employee_id):
		return _work_assignment[employee_id]

	# 找一个还没被分配出去的工作地点
	for loc in get_by_type(Location.TYPE.WORK_PLACE):
		if not _work_assignment.values().has(loc):
			_work_assignment[employee_id] = loc
			return loc
	
	push_warning("LocationManager: 没有空闲的工作地点，员工 %s 未分配" % employee_id)
	return null
	
## 查询某个员工被分配到的工作地点
func get_work_location(employee_id: String) -> Location:
	return _work_assignment.get(employee_id, null)

## 释放某个员工的工作地点（员工离职 / 场景重置）
func release_work_location(employee_id: String) -> void:
	_work_assignment.erase(employee_id)

## 清空所有分配（切场景 / 重开）
func clear_assignments() -> void:
	_work_assignment.clear()

# 
func find_employee_at_workplace(exclude: Employee = null) -> Employee:
	var candidates: Array[Employee] = []
	for loc in get_by_type(Location.TYPE.WORK_PLACE):
		if loc.who_occupy and loc.who_occupy != exclude:
			candidates.append(loc.who_occupy)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
