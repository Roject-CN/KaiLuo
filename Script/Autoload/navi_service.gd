extends Node
# nav_service.gd

var navigation_layer: TileMapLayer
var path_layer: TileMapLayer   # 只用于 debug，后面可以拿掉

var astar := AStarGrid2D.new()

# 本帧要绘制的路径集合，_process 里统一画
var _pending_paths: Array = []   # Array[Array[Vector2i]]


func set_up(navi : TileMapLayer, path : TileMapLayer) -> void:
	navigation_layer = navi
	path_layer = path
	
	if not (navigation_layer and path_layer):
		push_error("NavService: navigation_layer 未设置")
		return
	if not navigation_layer.tile_set:
		push_error("NavService: navigation_layer 没有设置 tile_set，无法建立导航栅格")
		return

	astar.region = navigation_layer.get_used_rect()
	astar.cell_size = Vector2(navigation_layer.tile_set.tile_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

	#把没有tile的部分设置为实心，不允许
	var used_rect := navigation_layer.get_used_rect()
	for x in range(used_rect.position.x, used_rect.end.x):
		for y in range(used_rect.position.y, used_rect.end.y):
			var cell := Vector2i(x, y)
			if navigation_layer.get_cell_source_id(cell) == -1:
				astar.set_point_solid(cell, true)


#把全局坐标转换成navi_player层的序列坐标
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return navigation_layer.local_to_map(
		navigation_layer.to_local(world_pos)
	)

#把navi_player层的序列坐标转换成全局坐标
func cell_to_world(cell: Vector2i) -> Vector2:
	return navigation_layer.to_global(
		navigation_layer.map_to_local(cell)
	)

#检测是否能够导航
func is_walkable(cell: Vector2i) -> bool:
	if not astar.region.has_point(cell):
		print("false1")
		return false
	if astar.is_point_solid(cell):
		print("false2")
		return false
	return true


## 请求绘制一条路径。本帧内会被累积，_process 里统一画。
func draw_path(id_path: Array[Vector2i]) -> void:
	if path_layer == null:
		return
	_pending_paths.append(id_path)


func _process(_delta: float) -> void:
	if _pending_paths.is_empty():
		return
	if path_layer == null:
		_pending_paths.clear()
		return

	path_layer.clear()
	for id_path in _pending_paths:
		for cell in id_path:
			path_layer.set_cell(cell, 0, Vector2i(0, 0))
	_pending_paths.clear()


# 返回格子路径，交给调用方决定怎么转
func find_id_path(from_world: Vector2, to_world: Vector2) -> Array[Vector2i]:
	var from_cell := world_to_cell(from_world)
	var to_cell := world_to_cell(to_world)
	if not is_walkable(from_cell): 
		return []
	if not is_walkable(to_cell): 
		return []
	var id_path := astar.get_id_path(from_cell, to_cell) 
	draw_path(id_path)
	return id_path

# 便捷版：直接返回世界坐标路径，供 Employee 用
func find_world_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var id_path := find_id_path(from_world, to_world)
	if id_path.is_empty(): return PackedVector2Array()

	var world_path := PackedVector2Array()
	for i in range(1, id_path.size()):
		world_path.append(cell_to_world(id_path[i]))
	return world_path
	

## 只判定「能不能走到」，不画调试路径（供导航发起前预检）。
## find_world_path 在两端不可走时也返回空数组，所以不能拿空数组当失败判据。
func has_path(from_world: Vector2, to_world: Vector2) -> bool:
	var from_cell := world_to_cell(from_world)
	var to_cell := world_to_cell(to_world)
	if from_cell == to_cell:
		return true
	if not is_walkable(from_cell) or not is_walkable(to_cell):
		return false
	return not astar.get_id_path(from_cell, to_cell).is_empty()

## 在目标格周围找一格能站人的地方。
## min_distance：候选格中心到 target_world 的最小距离（像素）。
## 用途：两个人聊天时别贴在一起；调用方可以按精灵宽度给出下限。
## 先找相邻一圈，都太近再退到外圈；同一圈里取满足距离的最近一格。
func find_stand_cell(target_world: Vector2, min_distance: float = 0.0) -> Variant:
	var center := world_to_cell(target_world)

	for ring in range(1, 3):
		var best: Variant = null
		var best_distance := INF
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var cell := center + Vector2i(dx, dy)
				if not is_walkable(cell):
					continue
				var distance := cell_to_world(cell).distance_to(target_world)
				if distance < min_distance or distance >= best_distance:
					continue
				best_distance = distance
				best = cell
		if best != null:
			return best

	return null
