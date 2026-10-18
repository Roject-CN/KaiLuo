extends EmployeeState


func state_enter() -> void:
	#if employee.work_place == null:
		#return
	var target := employee.work_place.return_global_position()
	employee.navigate(target)
	

func state_process(_delta : float) -> void:
	pass

func state_exit() -> void:
	pass
