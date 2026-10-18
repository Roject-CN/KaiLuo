class_name SessionBook
extends Node

## 会话登记表：谁在聊、谁被占用。只管增删查，不推台词、不切状态。

signal session_opened(session: ChatSession)
signal session_closed(session: ChatSession)

var _sessions: Array[ChatSession] = []
var _busy: Dictionary = {}      # Employee -> ChatSession


func is_busy(employee: Employee) -> bool:
	return _busy.has(employee)


func get_session(employee: Employee) -> ChatSession:
	return _busy.get(employee, null) as ChatSession


func has(session: ChatSession) -> bool:
	return _sessions.has(session)


## 返回副本：调用方遍历时可能触发关闭会话（关闭会改 _sessions）
func list_sessions() -> Array[ChatSession]:
	return _sessions.duplicate()


func open(a: Employee, b: Employee, meeting_point: Vector2) -> ChatSession:
	var session := ChatSession.new()
	session.a = a
	session.b = b
	session.meeting_point = meeting_point
	session.phase = ChatSession.Phase.MOVING
	_sessions.append(session)
	_busy[a] = session
	_busy[b] = session
	session_opened.emit(session)
	return session


func close(session: ChatSession) -> void:
	if not has(session):
		return
	_busy.erase(session.a)
	_busy.erase(session.b)
	_sessions.erase(session)
	session_closed.emit(session)
