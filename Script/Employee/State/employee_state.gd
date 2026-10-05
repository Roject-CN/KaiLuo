extends Node
class_name EmployeeState

enum STATE{
	GOWORK, 
	OFFWORK,
}
@export var state_name : STATE
var employee : Employee

func state_enter() -> void:
	pass

func state_process(_delta : float) -> void:
	pass

func state_exit() -> void:
	pass
