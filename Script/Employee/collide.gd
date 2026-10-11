extends Area2D
class_name EmployeeArea2D

@export var employee: Employee

## 排斥速度（像素/秒），只要进入范围就是恒定大小
@export var push_strength: float = 20.0

## 排斥速度上限比例：不超过 employee.speed 的这个比例
@export var max_push_ratio: float = 0.4

## 调试：画排斥半径
@export var debug_draw: bool = false

## 调试：绘制半径（不参与力计算，只用于 _draw 可视化）
@export var debug_radius: float = 8.0

## 开关：是否参与排斥
@export var can_colliding: bool = true


func _ready() -> void:
	if not employee:
		push_error("EmployeeArea2D: employee 未设置")
		return
	monitoring = true
	monitorable = true


func _physics_process(delta: float) -> void:
	if not employee or not can_colliding or not employee.is_navigating():
		return

	var push := _compute_push_velocity()
	if push == Vector2.ZERO:
		return

	# 限幅：多人叠加时避免弹飞
	var max_push := employee.speed * max_push_ratio
	if push.length() > max_push:
		push = push.normalized() * max_push

	# 直接把排斥位移加到员工身上。Employee 不需要知道这件事。
	employee.global_position += push * delta


# ---------------------------------------------------------------- 内部

## 计算来自其他员工的合力（像素/秒），恒力，不随距离衰减
func _compute_push_velocity() -> Vector2:
	var push := Vector2.ZERO

	for area in get_overlapping_areas():
		if not (area is EmployeeArea2D):
			continue
		var other := area as EmployeeArea2D
		if other == null or other == self:
			continue
		if other.employee == null:
			continue

		var diff := employee.global_position - other.employee.global_position
		if diff.length_squared() < 0.0001:
			# 完全重合，给个默认方向，避免两人卡死分不开
			diff = Vector2.RIGHT

		push += diff.normalized() * push_strength

	return push


func _draw() -> void:
	if debug_draw:
		draw_circle(Vector2.ZERO, debug_radius, Color(1, 0.3, 0.3, 0.15))
