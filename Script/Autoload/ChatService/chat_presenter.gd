class_name ChatPresenter
extends Node

## 表现层：把「谁在说哪句」落到员工头顶的 ChatLabel。
## 只订阅 DialogueRunner 的信号，不做业务判断；以后换打字机/世界空间气泡，只改这个节点。

var _shown: Dictionary = {}      # ChatSession -> Employee（这场对话当前气泡挂在谁头上）


func setup(runner: DialogueRunner) -> void:
	runner.line_started.connect(_on_line_started)
	runner.line_finished.connect(_on_line_finished)
	runner.dialogue_finished.connect(_on_dialogue_finished)


func _on_line_started(session: ChatSession, speaker: Employee, text: String) -> void:
	# 换人说话：先把上一条收掉（正常流程里上一条已经收过，这里是兜底）
	_hide_session(session)
	speaker.show_chat_line(text)
	_shown[session] = speaker


func _on_line_finished(session: ChatSession) -> void:
	_hide_session(session)


func _on_dialogue_finished(session: ChatSession) -> void:
	_hide_session(session)


## 订阅 ChatService.session_ended：会话被打断时也要清场
func clear_employees(a: Employee, b: Employee) -> void:
	for session in _shown.keys():
		var s := session as ChatSession
		if s != null and (s.a == a or s.b == b):
			_hide_session(s)
	if is_instance_valid(a):
		a.hide_chat_line()
	if is_instance_valid(b):
		b.hide_chat_line()


func _hide_session(session: ChatSession) -> void:
	var speaker: Employee = _shown.get(session, null)
	if speaker != null and is_instance_valid(speaker):
		speaker.hide_chat_line()
	_shown.erase(session)
