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
@export var occupy_delay : float = 1.0     # 停留多久才算占用
@export var area_radius : float = 12.0     # 检测半径，建议和格子尺寸接近

var busy := false
var who_occupy : Employee = null

var _area : Area2D
var _candidates : Array[Employee] = []     # 当前在区域内的员工
var _stay_timer : float = 0.0
var _first_candidate : Employee = null     # 正在计时的那个


func _ready() -> void:
	# 没手动挂 Area2D 就自己建一个
	_area = get_node_or_null("Area2D")
	if _area == null:
		_area = Area2D.new()
		_area.name = "Area2D"
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = area_radius
		shape.shape = circle
		_area.add_child(shape)
		add_child(_area)

	_area.area_entered.connect(_on_area_entered)
	_area.area_exited.connect(_on_area_exited)

	# 初始化时已经站在区域里的员工也算进来
	for a in _area.get_overlapping_areas():
		_on_area_entered(a)

func _on_area_entered(area: Area2D) -> void:
	var employee := area.get_parent() as Employee
	if employee == null:
		return
	if employee not in _candidates:
		_candidates.append(employee)

	if _first_candidate == null:
		_first_candidate = employee
		_stay_timer = 0.0

func _on_area_exited(area: Area2D) -> void:
	var employee := area.get_parent() as Employee
	if employee == null:
		return

	_candidates.erase(employee)

	# 计时的那个走了：换下一个候选
	if _first_candidate == employee:
		_first_candidate = null
		_stay_timer = 0.0
		if not _candidates.is_empty():
			_first_candidate = _candidates[0]

	# 占用者走了：释放
	if who_occupy == employee:
		release()

func _physics_process(delta: float) -> void:
	if busy:
		return
	if _first_candidate == null:
		return
	if not _candidates.has(_first_candidate):
		_first_candidate = null
		_stay_timer = 0.0
		return

	_stay_timer += delta
	if _stay_timer >= occupy_delay:
		occupy(_first_candidate)

func occupy(employee: Employee) -> void:
	busy = true
	who_occupy = employee

func release() -> void:
	busy = false
	who_occupy = null

func is_busy() -> bool:
	return busy

func return_global_position() -> Vector2:
	return global_position
