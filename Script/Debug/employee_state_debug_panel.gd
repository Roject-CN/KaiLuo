extends CanvasLayer
class_name EmployeeDebugPanel

## 员工状态调试面板（只给 test.tscn 这类测试场景用）
##
## 结构：CanvasLayer -> MarginContainer -> PanelContainer -> VBoxContainer
##   ├── 表头 HBoxContainer：员工 | 状态
##   ├── 员工行 HBoxContainer：员工1 | [上班] [下班]
##   └── 员工行 HBoxContainer：员工2 | [上班] [下班]
## 按钮按 EmployeeStateManager 下的状态子节点自动生成：以后新增一个状态文件
## 并挂到 EmployeeStateManager 下，面板会自动多出对应按钮，不用改这里的代码。

const PANEL_WIDTH := 176.0

## 当前状态按钮的高亮底色
const HIGHLIGHT_BG := Color(0.29, 0.56, 1.0, 0.40)
const COLOR_DARK_TEXT := Color(1, 1, 1)
const COLOR_LIGHT_TEXT := Color(0.12, 0.12, 0.12)

var column: VBoxContainer
var _margin: MarginContainer
var _employees: Array[Employee] = []
var _buttons: Dictionary = {}          # Employee -> Array[Button]
var _fingerprints: Dictionary = {}     # Employee -> 状态子节点数量


func _ready() -> void:
	layer = 100
	_build_shell()

	var timer := Timer.new()
	timer.name = "AutoRefresh"
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(refresh)
	add_child(timer)


# ---------------------------------------------------------------- 对外接口
## 注册一个要被调试的员工
func track(employee: Employee) -> void:
	if not employee:
		return
	if employee not in _employees:
		_employees.append(employee)
	_connect_manager(employee)
	rebuild()


## 状态有变化时刷新高亮，顺便侦测状态子节点的增删
func refresh() -> void:
	if not column or _employees.is_empty():
		return
	if _buttons.is_empty():
		rebuild()
		return
	if _employee_fingerprints() != _fingerprints:
		rebuild()
		return
	_update_highlight()


## 全部重建（状态增删后调用）
func rebuild() -> void:
	if not column:
		return
	_clear_row(column)

	if _employees.is_empty():
		return

	_make_column("员工")
	_make_column("状态")
	for employee in _employees:
		_add_employee_row(employee)

	_fingerprints = _employee_fingerprints()
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


# ---------------------------------------------------------------- 搭外壳
func _build_shell() -> void:
	_margin = MarginContainer.new()
	_margin.name = "Margin"
	_margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_margin.position = Vector2(8, 8)
	_margin.add_theme_constant_override("margin_left", 8)
	_margin.add_theme_constant_override("margin_top", 6)
	_margin.add_theme_constant_override("margin_right", 8)
	_margin.add_theme_constant_override("margin_bottom", 6)
	add_child(_margin)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	_margin.add_child(panel)

	column = VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)


## 建表头行，并返回这一列表头 Label（各列的表头会横向排在同一行里）
func _make_column(header_text: String) -> Label:
	var header_row: Node = column.get_node_or_null("Header")
	if not header_row:
		header_row = HBoxContainer.new()
		header_row.name = "Header"
		header_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		header_row.add_theme_constant_override("separation", 6)
		column.add_child(header_row)

	var title := Label.new()
	title.name = "Header_%s" % header_text
	title.text = header_text
	title.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(title)
	return title


## 一个员工一列 HBoxContainer：名字 Label + 各个状态按钮
func _add_employee_row(employee: Employee) -> void:
	var row := HBoxContainer.new()
	row.name = "Row_%s" % _safe_name(employee.name)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)

	row.add_child(_make_name_label(employee))
	_build_state_cells(row, employee)


func _make_name_label(employee: Employee) -> Label:
	var label := Label.new()
	label.name = "Name_%s" % _safe_name(employee.name)
	label.text = employee.employee_name
	label.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_state_cells(row: HBoxContainer, employee: Employee) -> void:
	var manager := employee.employee_state_manager
	if not manager:
		row.add_child(_make_note("员工没接 StateManager"))
		return

	var states := _state_nodes(manager)
	if states.is_empty():
		row.add_child(_make_note("没有状态子节点"))
		return

	var buttons: Array[Button] = []
	for state in states:
		buttons.append(_make_state_button(row, employee, state))
	_buttons[employee] = buttons


func _make_state_button(row: HBoxContainer, employee: Employee, state: EmployeeState) -> Button:
	var button := Button.new()
	button.name = "State_%s" % _safe_name(state.name)
	button.text = state_name_text(state)
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	button.set_meta("employee", employee)
	button.set_meta("state", state)
	button.pressed.connect(_on_state_button_pressed.bind(employee, state))
	button.gui_input.connect(_on_state_button_gui_input)
	row.add_child(button)
	return button


func _make_note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	return label


func _clear_row(host: VBoxContainer) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	_buttons.clear()


# ---------------------------------------------------------------- 按钮交互
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
	for employee in _employees:
		result[employee] = _state_nodes(employee.employee_state_manager).size()
	return result


func _safe_name(raw: String) -> String:
	var cleaned := ""
	for i in range(raw.length()):
		var ch := raw[i]
		if ch.is_valid_identifier():
			cleaned += ch
	return cleaned if cleaned != "" else "Node"
