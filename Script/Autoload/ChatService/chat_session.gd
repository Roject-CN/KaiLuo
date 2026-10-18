class_name ChatSession
extends RefCounted

## 一次聊天的数据。只存字段、不含逻辑：
##   生命周期（谁的会话、占用关系）由 SessionBook 管
##   台词推进（第几句、还剩多久）由 DialogueRunner 管
##   显示（挂在谁头上）由 ChatPresenter 管

enum Phase {
	MOVING,      # 正在走向会合点
	CHATTING,    # 已经站定、正在说话
}

var a: Employee
var b: Employee
var meeting_point: Vector2
var phase: Phase = Phase.MOVING

var dialogue: Array[String] = []
var dialogue_index: int = -1     # -1 = 还没说第一句
var line_timer: float = 0.0
