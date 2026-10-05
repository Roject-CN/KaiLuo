extends EmployeeState


func state_enter() -> void:
	var spawn := employee.global_position
	var target := employee.work_position
	var word_path := NaviService.find_world_path(spawn, target)
	employee.navigate(word_path)
	

func state_process(_delta : float) -> void:
	pass

func state_exit() -> void:
	pass
