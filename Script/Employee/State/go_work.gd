extends EmployeeState


func state_enter() -> void:
	var target := employee.work_position
	employee.navigate(target)
	

func state_process(_delta : float) -> void:
	pass

func state_exit() -> void:
	print("done!")
