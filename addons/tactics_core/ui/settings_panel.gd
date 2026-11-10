class_name SettingsPanel
extends PanelContainer
## The settings screen (spec §2a.5), usable from the title screen and the
## pause menu. Up/down picks a row, left/right (or confirm) changes it;
## changes apply at once and are saved when the panel closes.
##
## The panel reads its own input while open (keyboard, gamepad, mouse), so
## the owner only calls [method open] and waits for [signal closed].

## The panel closed (settings already saved).
signal closed

const PAGE_GENERAL: int = 0
const PAGE_CONTROLS: int = 1
const ROW_HEIGHT: float = 46.0

var settings: GameSettings
var selected: int = 0
## Action currently waiting for a key press (empty when not listening).
var listening_action: StringName = &""

var _page: int = PAGE_GENERAL
var _rows: Array[Dictionary] = []
var _row_nodes: Array[PanelContainer] = []
var _title := UiStyle.label("", 34, UiStyle.PANEL_BORDER)
var _list := VBoxContainer.new()
var _footer := UiStyle.label("", 20, UiStyle.TEXT_DIM)


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(_title)
	_list.add_theme_constant_override("separation", 2)
	box.add_child(_list)
	box.add_child(_footer)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


## Shows the panel for [param target] (the active settings by default).
func open(target: GameSettings = null) -> void:
	settings = target if target != null else GameSettings.current()
	_page = PAGE_GENERAL
	selected = 0
	listening_action = &""
	visible = true
	_rebuild()


func close() -> void:
	listening_action = &""
	visible = false
	settings.save()
	closed.emit()


## Row ids of the current page (for tests and tools).
func row_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for row: Dictionary in _rows:
		ids.append(row["id"])
	return ids


## Changes the selected row by [param direction] (-1 left, +1 right,
## 0 = confirm).
func activate(direction: int) -> void:
	if selected >= _rows.size():
		return
	var row_id: StringName = _rows[selected]["id"]
	match row_id:
		&"animation_speed":
			settings.animation_speed = posmod(settings.animation_speed + _step(direction), GameSettings.AnimationSpeed.size()) as GameSettings.AnimationSpeed
		&"text_speed":
			var index: int = maxi(0, GameSettings.TEXT_SPEEDS.find(settings.text_speed))
			settings.text_speed = GameSettings.TEXT_SPEEDS[posmod(index + _step(direction), GameSettings.TEXT_SPEEDS.size())]
		&"master_volume":
			settings.master_volume = _volume(settings.master_volume, direction)
		&"music_volume":
			settings.music_volume = _volume(settings.music_volume, direction)
		&"sfx_volume":
			settings.sfx_volume = _volume(settings.sfx_volume, direction)
		&"window_mode":
			settings.window_mode = posmod(settings.window_mode + _step(direction), GameSettings.WindowMode.size()) as GameSettings.WindowMode
		&"controller_layout":
			settings.controller_layout = posmod(settings.controller_layout + _step(direction), 3)
		&"colorblind_overlays":
			settings.colorblind_overlays = not settings.colorblind_overlays
		&"forecast_details":
			settings.forecast_details = not settings.forecast_details
		&"controls":
			if direction == 0:
				_show_page(PAGE_CONTROLS)
			return
		&"reset_keys":
			if direction == 0:
				settings.reset_keys()
		&"back":
			if direction == 0:
				_back()
			return
		_:
			if direction == 0 and GameSettings.REMAPPABLE_ACTIONS.has(row_id):
				listening_action = row_id
				_refresh()
			return
	settings.apply()
	_refresh()


## Binds the action being listened for to [param physical_keycode].
func bind_key(physical_keycode: int) -> void:
	if listening_action == &"":
		return
	settings.remap_key(listening_action, physical_keycode)
	listening_action = &""
	settings.apply()
	_refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if listening_action != &"":
		get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and not event.is_echo():
			var key := event as InputEventKey
			bind_key(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
		elif (event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
			listening_action = &""
			_refresh()
		return
	if event is InputEventMouse:
		return  # rows handle the mouse themselves
	var handled: bool = true
	if event.is_action_pressed(&"cursor_up", true):
		_move(-1)
	elif event.is_action_pressed(&"cursor_down", true):
		_move(1)
	elif event.is_action_pressed(&"cursor_left", true):
		activate(-1)
	elif event.is_action_pressed(&"cursor_right", true):
		activate(1)
	elif event.is_action_pressed(&"confirm") and not event.is_echo():
		activate(0)
	elif event.is_action_pressed(&"cancel") and not event.is_echo():
		_back()
	else:
		handled = event.is_action_type()
	if handled:
		get_viewport().set_input_as_handled()


func _back() -> void:
	if _page == PAGE_CONTROLS:
		_show_page(PAGE_GENERAL)
		selected = _index_of(&"controls")
		_refresh()
	else:
		close()


func _show_page(page: int) -> void:
	_page = page
	selected = 0
	_rebuild()


func _move(delta: int) -> void:
	selected = posmod(selected + delta, _rows.size())
	_refresh()


func _index_of(row_id: StringName) -> int:
	for i: int in _rows.size():
		if _rows[i]["id"] == row_id:
			return i
	return 0


static func _step(direction: int) -> int:
	return -1 if direction < 0 else 1


static func _volume(volume: int, direction: int) -> int:
	if direction == 0:
		return 0 if volume >= 100 else mini(100, volume + 10)
	return clampi(volume + 10 * direction, 0, 100)


func _rebuild() -> void:
	_rows.clear()
	if _page == PAGE_GENERAL:
		_title.text = tr("SETTINGS_TITLE")
		for row_id: StringName in [&"animation_speed", &"text_speed", &"master_volume", &"music_volume", &"sfx_volume", &"window_mode", &"controller_layout", &"colorblind_overlays", &"forecast_details", &"controls", &"back"]:
			_rows.append({"id": row_id, "label": "SETTINGS_" + String(row_id).to_upper()})
	else:
		_title.text = tr("SETTINGS_CONTROLS")
		for action: StringName in GameSettings.REMAPPABLE_ACTIONS:
			_rows.append({"id": action, "label": "ACTION_" + String(action).to_upper()})
		_rows.append({"id": &"reset_keys", "label": "SETTINGS_RESET_KEYS"})
		_rows.append({"id": &"back", "label": "SETTINGS_BACK"})
	for node: PanelContainer in _row_nodes:
		_list.remove_child(node)
		node.queue_free()
	_row_nodes.clear()
	for i: int in _rows.size():
		_row_nodes.append(_make_row(i))
	_refresh()


func _make_row(index: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(720, ROW_HEIGHT if _page == PAGE_GENERAL else 38.0)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var line := HBoxContainer.new()
	row.add_child(line)
	var name_label := UiStyle.label(tr(_rows[index]["label"]), 28 if _page == PAGE_GENERAL else 24)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var value_label := UiStyle.label("", 28 if _page == PAGE_GENERAL else 24, UiStyle.PANEL_BORDER)
	value_label.name = "Value"
	line.add_child(value_label)
	row.mouse_entered.connect(func() -> void:
		if listening_action == &"":
			selected = index
			_refresh())
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and listening_action == &"":
			var button: MouseButton = (event as InputEventMouseButton).button_index
			if button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT:
				selected = index
				activate(0 if button == MOUSE_BUTTON_LEFT and not _is_value_row(index) else (1 if button == MOUSE_BUTTON_LEFT else -1))
				accept_event())
	_list.add_child(row)
	return row


func _is_value_row(index: int) -> bool:
	var row_id: StringName = _rows[index]["id"]
	return _page == PAGE_GENERAL and not row_id in [&"controls", &"back"]


func _value_text(row_id: StringName) -> String:
	match row_id:
		&"animation_speed":
			return tr(["SETTINGS_ANIM_NORMAL", "SETTINGS_ANIM_FAST", "SETTINGS_ANIM_INSTANT"][settings.animation_speed])
		&"text_speed":
			var index: int = maxi(0, GameSettings.TEXT_SPEEDS.find(settings.text_speed))
			return tr(["SETTINGS_TEXT_SLOW", "SETTINGS_TEXT_NORMAL", "SETTINGS_TEXT_FAST", "SETTINGS_TEXT_INSTANT"][index])
		&"master_volume":
			return _bar(settings.master_volume)
		&"music_volume":
			return _bar(settings.music_volume)
		&"sfx_volume":
			return _bar(settings.sfx_volume)
		&"window_mode":
			return tr(["SETTINGS_WINDOWED", "SETTINGS_FULLSCREEN"][settings.window_mode])
		&"controller_layout":
			return tr(["SETTINGS_PAD_AUTO", "SETTINGS_PAD_NINTENDO", "SETTINGS_PAD_STANDARD"][settings.controller_layout])
		&"colorblind_overlays", &"forecast_details":
			return tr("SETTINGS_ON") if bool(settings.get(row_id)) else tr("SETTINGS_OFF")
		&"controls", &"back", &"reset_keys":
			return ""
	if row_id == listening_action:
		return tr("SETTINGS_PRESS_KEY")
	return InputHints.key_name(row_id)


static func _bar(volume: int) -> String:
	return "%s  %3d" % ["■".repeat(volume / 10) + "□".repeat(10 - volume / 10), volume]


func _refresh() -> void:
	for i: int in _row_nodes.size():
		var style := StyleBoxFlat.new()
		style.bg_color = UiStyle.HIGHLIGHT if i == selected else Color.TRANSPARENT
		style.set_corner_radius_all(4)
		style.content_margin_left = 14
		style.content_margin_right = 14
		_row_nodes[i].add_theme_stylebox_override("panel", style)
		var value: Label = _row_nodes[i].get_child(0).get_child(1) as Label
		value.text = _value_text(_rows[i]["id"])
	_footer.text = InputHints.fill(tr("SETTINGS_HINT_LISTENING" if listening_action != &"" else ("SETTINGS_HINT" if _page == PAGE_GENERAL else "SETTINGS_HINT_CONTROLS")))
	size = Vector2.ZERO
	reset_size()
	position = ((get_viewport_rect().size - size) * 0.5).floor()
