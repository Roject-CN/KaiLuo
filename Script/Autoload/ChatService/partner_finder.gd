class_name PartnerFinder
extends Node

## 只回答两个问题：找谁聊、在哪聊。
## 不做会话登记，也不切任何状态——那些属于 ChatService / SessionBook。

## 会合点与对方的最小距离（像素）。
## 16 = 一格；想彻底不叠在一起，把它调到 32（两格）即可，不用改代码。
@export var min_stand_distance: float = 16.0

var _location_manager: LocationManager


## 返回 {"employee": Employee, "meeting_point": Vector2}；找不到搭档或没有站位时返回 {}
func find_partner(from: Employee) -> Dictionary:
	var lm := _get_location_manager()
	if lm == null:
		push_error("ChatService/PartnerFinder: 找不到 LocationManager")
		return {}

	var candidates: Array[Employee] = []
	for loc in lm.get_by_type(Location.TYPE.WORK_PLACE):
		if loc.who_occupy and loc.who_occupy != from:
			candidates.append(loc.who_occupy)
	if candidates.is_empty():
		return {}

	var partner: Employee = candidates[randi() % candidates.size()]
	var stand_cell = NaviService.find_stand_cell(partner.global_position, min_stand_distance)
	if stand_cell == null:
		return {}

	return {"employee": partner, "meeting_point": NaviService.cell_to_world(stand_cell)}


func _get_location_manager() -> LocationManager:
	if not is_instance_valid(_location_manager):
		_location_manager = get_tree().get_first_node_in_group("location_manager") as LocationManager
	return _location_manager
