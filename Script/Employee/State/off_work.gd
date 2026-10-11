extends EmployeeState

## 下班：走回出生点
func state_enter() -> void:
	var target := employee.spawn_position
	employee.navigate(target)

func state_process(_delta : float) -> void:
	pass

func state_exit() -> void:
	pass
