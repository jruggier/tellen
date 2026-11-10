class_name ResultPanel
extends PanelContainer
## Victory / defeat screen.

var _box := VBoxContainer.new()


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows the result: [param victory], plus lines of [param details].
func show_result(victory: bool, details: PackedStringArray, prompt_text: String = "") -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var title := UiStyle.label(tr("UI_VICTORY") if victory else tr("UI_DEFEAT"), 96, UiStyle.PANEL_BORDER if victory else UiStyle.BAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	for line: String in details:
		var label := UiStyle.label(line, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(label)
	var prompt := UiStyle.label(prompt_text if not prompt_text.is_empty() else tr("UI_RESULT_PROMPT"), 24, UiStyle.TEXT_DIM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(prompt)
	visible = true
	size = Vector2.ZERO
	reset_size()
	position = (get_viewport_rect().size - size) * 0.5
