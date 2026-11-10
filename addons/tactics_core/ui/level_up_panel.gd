class_name LevelUpPanel
extends PanelContainer
## Level-up popup: new level and stat gains (spec §14). The owner closes it
## on confirm.

var _box := VBoxContainer.new()


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
	_box.add_child(UiStyle.label(tr("UI_LEVEL_UP"), 40, UiStyle.PANEL_BORDER))
	_box.add_child(UiStyle.label("%s   %s %d → %d" % [unit.get_display_name(), tr("UI_LEVEL"), new_level - 1, new_level], 28))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	for stat_id: StringName in ruleset.growable_stat_ids():
		var definition: StatDefinition = ruleset.get_stat(stat_id)
		var gain: int = gains.get_value(stat_id)
		grid.add_child(UiStyle.label(definition.get_abbreviation(), 26, UiStyle.TEXT_DIM))
		var value_text: String = str(unit.stats.get_value(stat_id)) + ("  +%d" % gain if gain > 0 else "")
		grid.add_child(UiStyle.label(value_text, 28, UiStyle.GOOD if gain > 0 else Color.WHITE))
	_box.add_child(grid)
	_box.add_child(UiStyle.label(tr("UI_PRESS_CONFIRM"), 20, UiStyle.TEXT_DIM))
	visible = true
	reset_size()
	position = (get_viewport_rect().size - size) * 0.5


func close() -> void:
	visible = false
