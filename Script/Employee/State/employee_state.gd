extends Node
class_name EmployeeState

enum STATE{
	GOWORK, 
	OFFWORK,
	GOCHAT,
	WAITING,
	CHATTING,
	GO_REST,
	GO_REPORT
}
@export var state_name : STATE
var employee : Employee

func state_enter() -> void:
	pass

func state_process(_delta : float) -> void:
	pass

func state_exit() -> void:
	pass
