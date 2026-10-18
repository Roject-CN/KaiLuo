class_name DialogueRunner
extends Node

## 台词推进器：只负责「下一句是谁、什么时候轮到」。
## 不碰 Employee、不碰 UI；显示交给 ChatPresenter 订阅信号完成。

signal line_started(session: ChatSession, speaker: Employee, text: String)
signal line_finished(session: ChatSession)
signal dialogue_finished(session: ChatSession)

var _book: SessionBook
var _seconds_per_char := 0.15
var _min_line_duration := 1.0
var _pool: Array[ChatDialogue] = []


func setup(book: SessionBook, seconds_per_char: float, min_line_duration: float, pool: Array[ChatDialogue]) -> void:
	_book = book
	_seconds_per_char = seconds_per_char
	_min_line_duration = min_line_duration
	_pool = pool


## 双方站定后由 ChatService 调用
func start(session: ChatSession) -> void:
	session.phase = ChatSession.Phase.CHATTING
	session.dialogue = _pick_dialogue()
	session.dialogue_index = -1
	session.line_timer = 0.0
	if session.dialogue.is_empty():
		dialogue_finished.emit(session)


func _physics_process(delta: float) -> void:
	if _book == null:
		return
	for session in _book.list_sessions():
		if session.phase != ChatSession.Phase.CHATTING:
			continue
		_tick(session, delta)


func _tick(session: ChatSession, delta: float) -> void:
	session.line_timer -= delta
	if session.line_timer > 0.0:
		return

	# 上一句到点：先通知收起，再推进
	if session.dialogue_index >= 0:
		line_finished.emit(session)

	session.dialogue_index += 1
	if session.dialogue_index >= session.dialogue.size():
		dialogue_finished.emit(session)
		return
	_start_line(session)


func _start_line(session: ChatSession) -> void:
	var text := session.dialogue[session.dialogue_index]
	# 约定：偶数下标 = 发起方 a，奇数下标 = 对方 b
	var speaker := session.a if session.dialogue_index % 2 == 0 else session.b
	session.line_timer = max(_min_line_duration, text.length() * _seconds_per_char)
	line_started.emit(session, speaker, text)


func _pick_dialogue() -> Array[String]:
	if _pool.is_empty():
		return []
	var d := _pool[randi() % _pool.size()]
	return d.lines.duplicate()
