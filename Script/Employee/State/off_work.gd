extends EmployeeState

## 下班：走回出生点
func state_enter() -> void:
	var from := employee.global_position
	var target := employee.spawn_position
	var world_path := NaviService.find_world_path(from, target)
	employee.navigate(world_path)

func state_process(_delta : float) -> void:
	pass

func state_exit() -> void:
	pass
