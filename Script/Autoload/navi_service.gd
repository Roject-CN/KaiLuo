extends Node
# nav_service.gd

var navigation_layer: TileMapLayer
var path_layer: TileMapLayer   # 只用于 debug，后面可以拿掉

var astar := AStarGrid2D.new()

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
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
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

#绘制导航路径
func draw_path(id_path: Array[Vector2i]) -> void:
	path_layer.clear()
	var path_atlas_coords := Vector2i(0, 0)  # 色块在图集里的位置
	for cell in id_path:
		path_layer.set_cell(cell, 0, path_atlas_coords)
		
# 返回格子路径，交给调用方决定怎么转
func find_id_path(from_world: Vector2, to_world: Vector2) -> Array[Vector2i]:
	var from_cell := world_to_cell(from_world)
	var to_cell := world_to_cell(to_world)
	if not is_walkable(from_cell): 
		print("出发点无法导航")
		return []
	if not is_walkable(to_cell): 
		print("目的地无法导航")
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
