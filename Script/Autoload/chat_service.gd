extends Node

## ChatService —— Autoload 场景的根节点，只做两件事：
##   1. 对外 API：request / notify_arrived / release
##   2. 把子节点的能力编排起来（依赖注入 + 信号接线）
## 具体职责都在子节点：
##   PartnerFinder   找搭档 + 会合点
##   SessionBook     会话登记与占用表
##   DialogueRunner  台词推进与计时
##   ChatPresenter   把台词写到员工头顶气泡

@onready var partner_finder: PartnerFinder = $PartnerFinder
@onready var session_book: SessionBook = $SessionBook
@onready var dialogue_runner: DialogueRunner = $DialogueRunner
@onready var chat_presenter: ChatPresenter = $ChatPresenter

var res1 := preload("res://Resource/test1.tres")

# ---------------------------------------------------------------- 配置
@export var seconds_per_char: float = 0.15
@export var min_line_duration: float = 1.0
@export var dialogue_pool: Array[ChatDialogue] = [res1]

# ---------------------------------------------------------------- 信号
signal session_ended(a: Employee, b: Employee)


func _ready() -> void:
	dialogue_runner.setup(session_book, seconds_per_char, min_line_duration, dialogue_pool)
	chat_presenter.setup(dialogue_runner)
	dialogue_runner.dialogue_finished.connect(_on_dialogue_finished)
	session_ended.connect(chat_presenter.clear_employees)


# ================================================================ 对外接口
## A 发起聊天请求，成功返回会话，失败返回 null
func request(from: Employee) -> ChatSession:
	if session_book.is_busy(from):
		return null

	var match_info := partner_finder.find_partner(from)
	if match_info.is_empty():
		return null

	var partner: Employee = match_info["employee"]
	var session := session_book.open(from, partner, match_info["meeting_point"])
	partner.enter_state(EmployeeState.STATE.WAITING)
	return session


## A 到达会合点，双方进入聊天
func notify_arrived(employee: Employee) -> void:
	var session := session_book.get_session(employee)
	if session == null:
		return
	if session.a != employee:
		return
	if session.phase != ChatSession.Phase.MOVING:
		return

	session.a.enter_state(EmployeeState.STATE.CHATTING)
	session.b.enter_state(EmployeeState.STATE.CHATTING)
	dialogue_runner.start(session)


## 一方中途放弃（被打断）
func release(employee: Employee) -> void:
	var session := session_book.get_session(employee)
	if session == null:
		return
	_end_session(session)


# ================================================================ 内部
func _end_session(session: ChatSession) -> void:
	# 已经关过就不再关：dialogue_finished 与 release 可能前后脚发生
	if not session_book.has(session):
		return

	session_book.close(session)
	session.a.enter_state(EmployeeState.STATE.GOWORK)
	session.b.enter_state(EmployeeState.STATE.GOWORK)
	session_ended.emit(session.a, session.b)


func _on_dialogue_finished(session: ChatSession) -> void:
	_end_session(session)
