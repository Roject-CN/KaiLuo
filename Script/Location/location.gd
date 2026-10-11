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

func return_global_position() -> Vector2:
	return self.global_position
