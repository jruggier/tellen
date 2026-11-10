class_name LevelUpPanel
extends PanelContainer
## Level-up popup: new level and stat gains (spec §14). The owner closes it
## on confirm.

var _box := VBoxContainer.new()
## Stat id → [value label, final text] for the gains still to reveal.
var _pending: Array[Array] = []


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows [param unit] reaching [param new_level] with [param gains].
func show_level_up(unit: UnitState, new_level: int, gains: StatBlock, ruleset: Ruleset) -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_pending.clear()
	_box.add_child(UiStyle.label(tr("UI_LEVEL_UP"), 40, UiStyle.PANEL_BORDER))
	_box.add_child(UiStyle.label("%s   %s %d → %d" % [unit.get_display_name(), tr("UI_LEVEL"), new_level - 1, new_level], 28))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	for stat_id: StringName in ruleset.growable_stat_ids():
		var definition: StatDefinition = ruleset.get_stat(stat_id)
		var gain: int = gains.get_value(stat_id)
		grid.add_child(UiStyle.label(definition.get_abbreviation(), 26, UiStyle.TEXT_DIM))
		var value_label := UiStyle.label(str(unit.stats.get_value(stat_id) - gain), 28)
		grid.add_child(value_label)
		if gain > 0:
			_pending.append([value_label, "%d  +%d" % [unit.stats.get_value(stat_id), gain]])
	_box.add_child(grid)
	_box.add_child(UiStyle.label(tr("UI_PRESS_CONFIRM"), 20, UiStyle.TEXT_DIM))
	visible = true
	reset_size()
	position = (get_viewport_rect().size - size) * 0.5


## Plays the jingle and reveals each stat gain in turn with a chime.
## [param time_scale] 0 reveals everything at once. Stops early if the
## panel is closed.
func reveal(time_scale: float = 1.0) -> void:
	Sfx.play(&"level_up")
	if time_scale > 0.0:
		await _wait(0.45 * time_scale)
	while not _pending.is_empty() and visible:
		var entry: Array = _pending.pop_front()
		var label: Label = entry[0]
		label.text = entry[1]
		label.add_theme_color_override("font_color", UiStyle.GOOD)
		if time_scale > 0.0:
			Sfx.play(&"stat_up", 1.0 + 0.04 * _pending.size())
			await _wait(0.16 * time_scale)
	_finish_reveal()


func close() -> void:
	_finish_reveal()
	visible = false


func _finish_reveal() -> void:
	for entry: Array in _pending:
		(entry[0] as Label).text = entry[1]
		(entry[0] as Label).add_theme_color_override("font_color", UiStyle.GOOD)
	_pending.clear()


func _wait(seconds: float) -> void:
	if seconds > 0.0 and is_inside_tree():
		await get_tree().create_timer(seconds).timeout
