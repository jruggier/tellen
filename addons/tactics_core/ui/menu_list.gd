class_name MenuList
extends PanelContainer
## A vertical command menu (action menu, weapon list, items...).
##
## Keyboard/gamepad navigation is driven by the owner through [method move]
## and [method accept] so one controller decides who gets input; the mouse
## works directly (hover selects, click accepts).

## An enabled option was accepted.
signal chosen(option_id: StringName)

const ROW_HEIGHT: float = 44.0

var selected: int = 0
var _options: Array[Dictionary] = []
var _rows: Array[PanelContainer] = []
var _box := VBoxContainer.new()
var _title := UiStyle.label("", 22, UiStyle.TEXT_DIM)


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	_box.add_theme_constant_override("separation", 2)
	add_child(_box)
	_box.add_child(_title)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


## Shows the menu with [param options] (dictionaries with [code]id[/code],
## [code]text[/code], optional [code]enabled[/code] and [code]detail[/code]).
## [param screen_position] is where the top-left corner should go (clamped
## to the screen).
func open(options: Array[Dictionary], screen_position: Vector2, title: String = "") -> void:
	_options = options
	_title.text = title
	_title.visible = not title.is_empty()
	for row: PanelContainer in _rows:
		_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	for i: int in options.size():
		_rows.append(_make_row(i))
	selected = 0
	if not _is_enabled(0):
		move(1)
	visible = true
	size = Vector2.ZERO
	reset_size()
	_place.call_deferred(screen_position)
	_refresh()


func close() -> void:
	visible = false


## Moves the highlight by [param delta], skipping disabled options.
func move(delta: int) -> void:
	if _options.is_empty():
		return
	var before: int = selected
	for step: int in _options.size():
		selected = posmod(selected + delta, _options.size())
		if _is_enabled(selected):
			break
	if selected != before:
		Sfx.play(&"menu_move")
	_refresh()


## Accepts the highlighted option (emits [signal chosen] if enabled).
func accept() -> void:
	if selected >= 0 and selected < _options.size() and _is_enabled(selected):
		Sfx.play(&"confirm")
		chosen.emit(StringName(_options[selected]["id"]))
	elif selected >= 0 and selected < _options.size():
		Sfx.play(&"error")


func selected_id() -> StringName:
	return StringName(_options[selected]["id"]) if selected < _options.size() else &""


func option_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for option: Dictionary in _options:
		ids.append(StringName(option["id"]))
	return ids


func _is_enabled(index: int) -> bool:
	return index < _options.size() and bool(_options[index].get("enabled", true))


func _make_row(index: int) -> PanelContainer:
	var option: Dictionary = _options[index]
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(260, ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 24)
	row.add_child(line)
	var color: Color = Color.WHITE if _is_enabled(index) else Color(0.5, 0.5, 0.55)
	var text := UiStyle.label(str(option["text"]), 28, color)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	if option.has("detail"):
		line.add_child(UiStyle.label(str(option["detail"]), 24, UiStyle.TEXT_DIM if _is_enabled(index) else color))
	row.mouse_entered.connect(func() -> void:
		if _is_enabled(index) and selected != index:
			selected = index
			Sfx.play(&"menu_move")
			_refresh())
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			selected = index
			_refresh()
			accept()
			accept_event())
	_box.add_child(row)
	return row


func _refresh() -> void:
	for i: int in _rows.size():
		var style := StyleBoxFlat.new()
		style.bg_color = UiStyle.HIGHLIGHT if i == selected else Color.TRANSPARENT
		style.set_corner_radius_all(4)
		style.content_margin_left = 12
		style.content_margin_right = 12
		_rows[i].add_theme_stylebox_override("panel", style)


func _place(screen_position: Vector2) -> void:
	var screen: Vector2 = get_viewport_rect().size
	position = Vector2(clampf(screen_position.x, 16, screen.x - size.x - 16), clampf(screen_position.y, 16, screen.y - size.y - 16))
