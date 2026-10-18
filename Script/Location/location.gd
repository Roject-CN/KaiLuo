extends Marker2D
class_name Location

enum TYPE {
	SPAWN_PLACE,
	WORK_PLACE,
	REST_PLACE,
	BOSS_PLACE,
	NULL
}

@export var type : TYPE

## 当前占用这个点位的员工。
## 占用由状态机显式调用 begin_use / end_use 设置，不再靠 Area2D 停留计时自动判定。
var who_occupy : Employee = null

## 排队顺序（先来先服务）。使用者在使用期间仍留在队首，离开时出队，下一个人自然递补。
var _queue: Array[Employee] = []

## 占用结束（可能由排队系统监听；目前状态机用轮询即可）
signal freed


# ================================================================ 占用
func begin_use(employee: Employee) -> void:
	who_occupy = employee


func end_use() -> void:
	if who_occupy == null:
		return
	who_occupy = null
	freed.emit()


func is_busy() -> bool:
	return who_occupy != null


# ================================================================ 排队
func queue_join(employee: Employee) -> void:
	if employee not in _queue:
		_queue.append(employee)


func queue_leave(employee: Employee) -> void:
	_queue.erase(employee)


func is_first(employee: Employee) -> bool:
	return not _queue.is_empty() and _queue[0] == employee


func queue_index(employee: Employee) -> int:
	return _queue.find(employee)


func queue_members() -> Array[Employee]:
	return _queue.duplicate()


func return_global_position() -> Vector2:
	return global_position
