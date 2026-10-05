extends CanvasLayer
class_name EmployeeDebugPanel

## 员工状态调试面板 —— 仅供测试场景使用，生产代码不需要为它改任何东西。
##
## 用法：把 Scene/Debug/EmployeeStateDebugPanel.tscn 作为一个节点放进测试场景即可。
## 面板会自己扫描所在场景里的 Employee，不需要在别的脚本里登记、也不需要信号配合。
## 不想要它就删掉那个节点。
##
## 场景结构（全部节点在编辑器里可见可改）：
##   DebugPanel (CanvasLayer)
##   └── Margin
##       └── Panel
##           └── Column
##               ├── RowTemplate                   ← 隐藏的模板行，按需复制
##               │   ├── NameLabel
##               │   └── StateButtons/StateButton  ← 隐藏的模板按钮，按需复制
##               ├── Header                        ← 表头（脚本按列生成）
##               └── Row_xxx                       ← 每个员工一行（克隆出来的）
##
## 脚本只做四件事：找员工、克隆模板、按状态子节点生成按钮、维护高亮。

const ROW_PREFIX := "Row_"

## 当前状态按钮的高亮底色
const HIGHLIGHT_BG := Color(0.29, 0.56, 1.0, 0.40)
const COLOR_DARK_TEXT := Color(1, 1, 1)
const COLOR_LIGHT_TEXT := Color(0.12, 0.12, 0.12)

## 场景里的节点都用 @onready 直接取，不用 @export 连线：
## 路径写死在这里，节点树在编辑器里照样可见可改。
@onready var row_template : HBoxContainer = $Margin/Panel/Column/RowTemplate
@onready var name_label_template : Label = $Margin/Panel/Column/RowTemplate/NameLabel
@onready var button_template : Button = $Margin/Panel/Column/RowTemplate/StateButtons/StateButton

## 按钮文字。留空则按下面的默认值；以后加状态只改这里，不用动生产代码。
@export var state_labels : Dictionary = {
	EmployeeState.STATE.GOWORK: "上班",
	EmployeeState.STATE.OFFWORK: "下班",
}

var _tracked: Array[Employee] = []          # 已登记的员工
var _buttons: Dictionary = {}               # Employee -> Array[Button]
var _fingerprints: Dictionary = {}          # Employee -> 状态子节点数量
var _last_state: Dictionary = {}            # Employee -> 上次看到的状态（用于轮询比对）
## 重建期间抑制 refresh 重入。否则 rebuild -> refresh -> rebuild 会无限递归。
var _mutating := false


func _ready() -> void:
	var missing: Array[String] = []
	if not row_template: missing.append("row_template")
	if not name_label_template: missing.append("name_label_template")
	if not button_template: missing.append("button_template")
	if not missing.is_empty():
		push_error("EmployeeDebugPanel: 场景里这些节点没找到：%s" % ", ".join(missing))
		return

	row_template.visible = false

	# 面板往往比测试脚本先 _ready（子节点在前），这时场景根还没挂上，
	# 等一帧再找员工，那时场景已经完整、员工的 _ready 也都跑完了
	if get_tree().current_scene:
		_tracked = _collect_employees()
		rebuild()
	else:
		_deferred_start.call_deferred()


func _deferred_start() -> void:
	_tracked = _collect_employees()
	rebuild()


## 自己找员工：从所在场景往下递归。不需要别的脚本登记。
## 优先认 "employee" 分组，没分组就按类型认。
func _collect_employees() -> Array[Employee]:
	var found: Array[Employee] = []
	for node in get_tree().get_nodes_in_group("employee"):
		var grouped := node as Employee
		if grouped and grouped not in found:
			found.append(grouped)
	if not found.is_empty():
		return found

	var scene := get_tree().current_scene
	if scene:
		_collect_in(scene, found)
	return found


func _collect_in(node: Node, found: Array[Employee]) -> void:
	var employee := node as Employee
	if employee:
		found.append(employee)
	for child in node.get_children():
		_collect_in(child, found)


## 每帧轮询当前状态：状态一变就挪高亮。不需要生产代码发信号。
func _process(_delta: float) -> void:
	refresh()


## 对外：手动登记一个员工（一般不需要，_ready 会自动找）
func track(employee: Employee) -> void:
	if not employee or not row_template:
		return
	if employee not in _tracked:
		_tracked.append(employee)
	rebuild()


# ---------------------------------------------------------------- 刷新
## 状态变了挪高亮；状态子节点增删了整块重建
func refresh() -> void:
	if _mutating or _tracked.is_empty():
		return
	if _employee_fingerprints() != _fingerprints:
		rebuild()
		return
	if _states_changed():
		_update_highlight()


func _states_changed() -> bool:
	for employee in _tracked:
		var current := _current_state(employee)
		if _last_state.get(employee, null) != current:
			return true
	return false


## 重建所有行。整段过程用 _mutating 挡住 refresh 的重入。
func rebuild() -> void:
	if not row_template or _mutating:
		return
	_mutating = true

	# 1) 清掉上一次建出来的行与表头：它们都是运行时生成的，
	#    场景里那份只是模板（隐藏的 RowTemplate）
	_clear_column()
	# 一个表头行里，每个格子对应一列
	var header_row := _make_header()
	_add_header_cell(header_row, "员工")
	for i in range(_state_column_count()):
		_add_header_cell(header_row, state_name_text(_state_column_state(i)))

	# 2) 每个员工一行：克隆模板
	for employee in _tracked:
		_fill_row(_spawn_row(), employee)

	_fingerprints = _employee_fingerprints()
	_mutating = false
	_update_highlight()


## 表头是一个横排：第一个格子是"员工"，之后每个状态一个格子。
## 状态列以第一个员工的状态子节点为准（同一批员工通常共用同一套状态）。
func _make_header() -> HBoxContainer:
	var column := row_template.get_parent()
	var header_row := HBoxContainer.new()
	header_row.name = _unique_name(column, "Header")
	header_row.add_theme_constant_override("separation", 6)
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header_row)
	return header_row


func _add_header_cell(header_row: HBoxContainer, text: String) -> void:
	var title := name_label_template.duplicate() as Label
	title.name = _unique_name(header_row, "HeaderLabel")
	title.text = text
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(title)


func _state_column_count() -> int:
	if _tracked.is_empty():
		return 0
	return _state_nodes(_tracked[0].employee_state_manager).size()


func _state_column_state(index: int) -> EmployeeState:
	if _tracked.is_empty():
		return null
	var states := _state_nodes(_tracked[0].employee_state_manager)
	if index < 0 or index >= states.size():
		return null
	return states[index]


## 只清运行时建出来的行（表头 + Row_xxx），保留隐藏的 RowTemplate
func _clear_column() -> void:
	var column := row_template.get_parent()
	for child in column.get_children():
		if child == row_template:
			continue
		if child is HBoxContainer:
			column.remove_child(child)
			child.queue_free()


## 状态 -> 按钮文字
func state_name_text(state: EmployeeState) -> String:
	if state_labels.has(state.state_name):
		return str(state_labels[state.state_name])
	return state.name


# ---------------------------------------------------------------- 一行与按钮
func _spawn_row() -> HBoxContainer:
	var row := row_template.duplicate() as HBoxContainer
	row.name = "Row_新员工"
	row.visible = true
	# 立刻把克隆来的示例按钮摘掉。用 remove_child + queue_free，
	# 而不是只 queue_free —— 后者要到帧末才生效，本帧内它仍在树上，
	# 会被当成"已存在的按钮"。
	var button_host := row.get_node_or_null("StateButtons")
	if button_host:
		for button in button_host.get_children():
			button_host.remove_child(button)
			button.queue_free()
	row_template.get_parent().add_child(row)
	return row


func _fill_row(row: HBoxContainer, employee: Employee) -> void:
	row.set_meta("employee", employee)
	row.name = _unique_name(row.get_parent(), ROW_PREFIX + _safe_name(employee.employee_name))

	var name_label := row.get_node_or_null("NameLabel") as Label
	if name_label:
		name_label.text = employee.employee_name

	var button_host := row.get_node_or_null("StateButtons") as HBoxContainer
	if not button_host:
		return

	# 行是刚克隆出来的，里面只有一个示例按钮，已经在 _spawn_row 里摘掉了，
	# 所以这里直接按状态列表生成即可
	var buttons: Array[Button] = []
	for state in _state_nodes(employee.employee_state_manager):
		buttons.append(_spawn_button(button_host, employee, state))
	_buttons[employee] = buttons


func _spawn_button(host: HBoxContainer, employee: Employee, state: EmployeeState) -> Button:
	var button := button_template.duplicate() as Button
	button.name = _unique_name(host, _safe_name(state.name))
	button.text = state_name_text(state)
	button.visible = true
	button.set_meta("employee", employee)
	button.set_meta("state", state)
	button.pressed.connect(_on_state_button_pressed.bind(employee, state))
	button.gui_input.connect(_on_state_button_gui_input)
	host.add_child(button)
	return button


func _on_state_button_pressed(employee: Employee, state: EmployeeState) -> void:
	var manager := employee.employee_state_manager
	if not manager:
		return
	manager.transition(state)
	_update_highlight()


func _on_state_button_gui_input(event: InputEvent) -> void:
	# 面板里的鼠标事件到此为止，别让测试场景的“点击导航”把它当成场景点击
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var viewport := get_viewport()
		if viewport:
			viewport.set_input_as_handled()


# ---------------------------------------------------------------- 高亮
func _update_highlight() -> void:
	for employee in _buttons:
		var current := _current_state(employee)
		_last_state[employee] = current
		for button in _buttons[employee]:
			var is_active: bool = current != null and button.get_meta("state") == current
			button.set_pressed_no_signal(is_active)
			_style_button(button, is_active)


func _style_button(button: Button, is_active: bool) -> void:
	button.add_theme_color_override("font_color", COLOR_LIGHT_TEXT if is_active else COLOR_DARK_TEXT)
	button.add_theme_color_override("font_pressed_color", COLOR_LIGHT_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_LIGHT_TEXT)

	if not is_active:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("pressed")
		button.remove_theme_stylebox_override("hover")
		return

	var style := StyleBoxFlat.new()
	style.bg_color = HIGHLIGHT_BG
	style.set_corner_radius_all(3)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.75, 1.0, 0.9)
	style.content_margin_left = 6
	style.content_margin_right = 6
	for state_name in ["normal", "pressed", "hover"]:
		button.add_theme_stylebox_override(state_name, style)


# ---------------------------------------------------------------- 工具
func _current_state(employee: Employee) -> EmployeeState:
	var manager := employee.employee_state_manager
	if not manager:
		return null
	return manager.get_current_state()


func _state_nodes(manager: EmployeeStateManager) -> Array[EmployeeState]:
	var found: Array[EmployeeState] = []
	if not manager:
		return found
	for child in manager.get_children():
		if child is EmployeeState and not found.has(child):
			found.append(child)
	return found


func _employee_fingerprints() -> Dictionary:
	var result := {}
	for employee in _tracked:
		result[employee] = _state_nodes(employee.employee_state_manager).size()
	return result


## Godot 节点名用：中文会被过滤掉，这时回退到 "Node"，由 _unique_name 保证不重名
func _safe_name(raw: String) -> String:
	var cleaned := ""
	for i in range(raw.length()):
		var ch := raw[i]
		if ch.is_valid_identifier():
			cleaned += ch
	return cleaned if cleaned != "" else "Node"


## 在 parent 下找一个不重名的名字，避免 Godot 自动加 @2 后缀
func _unique_name(parent: Node, wanted: String) -> String:
	if not parent.has_node(NodePath(wanted)):
		return wanted
	var index := 2
	while parent.has_node(NodePath("%s%d" % [wanted, index])):
		index += 1
	return "%s%d" % [wanted, index]
