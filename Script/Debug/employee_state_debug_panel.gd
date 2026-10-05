extends CanvasLayer
class_name EmployeeDebugPanel

## 员工状态调试面板（只给 test.tscn 这类测试场景用）
##
## 场景结构见 Scene/Debug/EmployeeStateDebugPanel.tscn，全部节点都在编辑器里可见可改：
##   DebugPanel (CanvasLayer)
##   └── Margin
##       └── Panel
##           └── Column
##               ├── Header
##               │   ├── NameColumn/HeaderLabel    "员工"
##               │   └── StateColumn/HeaderLabel   "状态"
##               ├── RowTemplate                   ← 隐藏的模板行，按需复制
##               │   ├── NameLabel
##               │   └── StateButtons/StateButton  ← 隐藏的模板按钮，按需复制
##               └── Row_xxx                       ← 每个员工一行（克隆出来的）
##
## 脚本只做三件事：克隆模板、把状态子节点接到按钮上、维护高亮。

const ROW_PREFIX := "Row_"

## 当前状态按钮的高亮底色
const HIGHLIGHT_BG := Color(0.29, 0.56, 1.0, 0.40)
const COLOR_DARK_TEXT := Color(1, 1, 1)
const COLOR_LIGHT_TEXT := Color(0.12, 0.12, 0.12)

## 场景里的节点都用 @onready 直接取，不用 @export 连线：
## 路径写死在这里，节点树在编辑器里照样可见可改。
@onready var name_column : VBoxContainer = $Margin/Panel/Column/Header/NameColumn
@onready var state_column : VBoxContainer = $Margin/Panel/Column/Header/StateColumn
@onready var row_template : HBoxContainer = $Margin/Panel/Column/RowTemplate
@onready var name_label_template : Label = $Margin/Panel/Column/RowTemplate/NameLabel
@onready var button_template : Button = $Margin/Panel/Column/RowTemplate/StateButtons/StateButton

## 员工在哪一层由 test.gd 在运行时告诉面板（见 track_employees）
var employee_manager : Node2D

var _buttons: Dictionary = {}          # Employee -> Array[Button]
var _fingerprints: Dictionary = {}     # Employee -> 状态子节点数量
var _tracked: Array[Employee] = []     # 已登记、需要显示成行的员工
## 重建期间抑制 refresh 重入。否则 rebuild -> track -> refresh -> rebuild 会无限递归。
var _mutating := false


func _ready() -> void:
	var missing: Array[String] = []
	if not name_column: missing.append("name_column")
	if not state_column: missing.append("state_column")
	if not row_template: missing.append("row_template")
	if not name_label_template: missing.append("name_label_template")
	if not button_template: missing.append("button_template")
	if not missing.is_empty():
		push_error("EmployeeDebugPanel: 场景里这些 @export 没接上：%s" % ", ".join(missing))
		return

	if row_template:
		row_template.visible = false


# ---------------------------------------------------------------- 对外接口
## 把 manager 下面的员工全部登记上来。由 test.gd 在 _ready 里调用——
## 面板的 _ready 跑在员工之后，那时 test.gd 还没执行，拿不到 manager。
func track_employees(manager: Node) -> void:
	employee_manager = manager as Node2D
	for employee in _find_employees(manager):
		_tracked.append(employee)
		_connect_manager(employee)
	rebuild()


## 登记一个员工（只登记，行和按钮由 rebuild 统一生成）
func track(employee: Employee) -> void:
	if not employee or not row_template:
		return
	if employee not in _tracked:
		_tracked.append(employee)
	_connect_manager(employee)
	rebuild()


## 状态变化时刷新高亮，并侦测状态子节点的增删
func refresh() -> void:
	if _mutating or _tracked.is_empty():
		return
	if _employee_fingerprints() != _fingerprints:
		rebuild()
		return
	_update_highlight()


## 重建所有行。整段过程用 _mutating 挡住 refresh 的重入。
func rebuild() -> void:
	if not row_template or _mutating:
		return
	_mutating = true

	# 1) 该删除的行：不再被登记、或标记为待删除的
	for row in _rows():
		var owner := _row_employee(row)
		if owner == null or owner not in _tracked or row.get_meta("pending_deletion", false):
			row.set_meta("pending_deletion", true)
			row.queue_free()

	# 2) 每个员工一行：已经有行的复用，没有的克隆模板
	for employee in _tracked:
		var row := _row_for(employee)
		if not row:
			row = _spawn_row()
		_fill_row(row, employee)

	_fingerprints = _employee_fingerprints()
	_mutating = false
	_update_highlight()


## 状态枚举 -> 显示文字
func state_name_text(state: EmployeeState) -> String:
	match state.state_name:
		EmployeeState.STATE.GOWORK:
			return "上班"
		EmployeeState.STATE.OFFWORK:
			return "下班"
		_:
			return state.name


# ---------------------------------------------------------------- 行走与按钮
func _spawn_row() -> HBoxContainer:
	var row := row_template.duplicate() as HBoxContainer
	row.name = "Row_新员工"
	row.visible = true
	row.set_meta("employee", null)
	row.set_meta("pending_deletion", false)
	for child in row.get_children():
		if child.name == "StateButtons":
			for button in child.get_children():
				button.queue_free()
	row_template.get_parent().add_child(row)
	return row


func _rows() -> Array[HBoxContainer]:
	var found: Array[HBoxContainer] = []
	if not row_template:
		return found
	for child in row_template.get_parent().get_children():
		var row := child as HBoxContainer
		if row and row != row_template:
			found.append(row)
	return found


func _row_employee(row: HBoxContainer) -> Employee:
	if not row.has_meta("employee"):
		return null
	return row.get_meta("employee") as Employee


func _row_for(employee: Employee) -> HBoxContainer:
	for row in _rows():
		if row.get_meta("pending_deletion", false):
			continue
		if _row_employee(row) == employee:
			return row
	return null


func _fill_row(row: HBoxContainer, employee: Employee) -> void:
	row.set_meta("employee", employee)
	row.name = ROW_PREFIX + _safe_name(employee.employee_name)

	var name_label := row.get_node_or_null("NameLabel") as Label
	if name_label:
		name_label.text = employee.employee_name

	var button_host := row.get_node_or_null("StateButtons") as HBoxContainer
	if not button_host:
		return

	var states := _state_nodes(employee.employee_state_manager)

	# 现有按钮已经和状态列表对得上就复用，不要每帧重建按钮
	var existing: Array[Button] = []
	for child in button_host.get_children():
		var button := child as Button
		if button and button != button_template:
			existing.append(button)
	if _buttons_match(existing, states):
		_buttons[employee] = existing
		return

	for button in existing:
		button_host.remove_child(button)
		button.queue_free()

	var buttons: Array[Button] = []
	for state in states:
		buttons.append(_spawn_button(button_host, employee, state))
	_buttons[employee] = buttons


func _buttons_match(buttons: Array[Button], states: Array[EmployeeState]) -> bool:
	if buttons.size() != states.size():
		return false
	for i in range(buttons.size()):
		if buttons[i].get_meta("state", null) != states[i]:
			return false
	return true


func _spawn_button(host: HBoxContainer, employee: Employee, state: EmployeeState) -> Button:
	var button := button_template.duplicate() as Button
	button.name = _safe_name(state.name)
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
	refresh()


func _on_state_button_gui_input(event: InputEvent) -> void:
	# 面板里的鼠标事件到此为止，别让 test.gd 的“点击导航”把它当成场景点击
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var viewport := get_viewport()
		if viewport:
			viewport.set_input_as_handled()


# ---------------------------------------------------------------- 高亮
func _update_highlight() -> void:
	for employee in _buttons:
		var manager: EmployeeStateManager = employee.employee_state_manager
		var current: EmployeeState = manager.get_current_state() if manager else null
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
## 在 root 下面递归找所有 Employee
func _find_employees(root: Node) -> Array[Employee]:
	var found: Array[Employee] = []
	if not root:
		return found
	for child in root.get_children():
		var employee := child as Employee
		if employee:
			found.append(employee)
		found.append_array(_find_employees(child))
	return found


func _state_nodes(manager: EmployeeStateManager) -> Array[EmployeeState]:
	var found: Array[EmployeeState] = []
	if not manager:
		return found
	for child in manager.get_children():
		if child is EmployeeState and not found.has(child):
			found.append(child)
	return found


func _connect_manager(employee: Employee) -> void:
	var manager := employee.employee_state_manager
	if not manager:
		return
	if not manager.state_changed.is_connected(_on_state_changed):
		manager.state_changed.connect(_on_state_changed)


func _on_state_changed(_to_state: EmployeeState) -> void:
	refresh()


func _employee_fingerprints() -> Dictionary:
	var result := {}
	for employee in _tracked:
		result[employee] = _state_nodes(employee.employee_state_manager).size()
	return result


func _safe_name(raw: String) -> String:
	var cleaned := ""
	for i in range(raw.length()):
		var ch := raw[i]
		if ch.is_valid_identifier():
			cleaned += ch
	return cleaned if cleaned != "" else "Node"
