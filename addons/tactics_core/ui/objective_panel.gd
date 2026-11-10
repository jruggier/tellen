class_name ObjectivePanel
extends PanelContainer
## Lists the map's objectives (with progress) and defeat conditions.
## Shown from the pause menu; closes on confirm or cancel.

var _box := VBoxContainer.new()


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_objectives(state: BattleState, objectives: Array[Objective], defeat_conditions: Array[DefeatCondition]) -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_box.add_child(UiStyle.label(tr("UI_OBJECTIVE_TITLE"), 34, UiStyle.PANEL_BORDER))
	for objective: Objective in ObjectiveRules.effective_objectives(objectives):
		var line: String = objective.describe()
		var progress: String = objective.progress(state)
		if not progress.is_empty():
			line += "   (%s)" % progress
		_box.add_child(UiStyle.label(line, 28))
	_box.add_child(UiStyle.label(tr("UI_DEFEAT_TITLE"), 26, UiStyle.TEXT_DIM))
	for condition: DefeatCondition in ObjectiveRules.effective_defeat_conditions(defeat_conditions):
		_box.add_child(UiStyle.label(condition.describe(), 24, UiStyle.BAD))
	_box.add_child(UiStyle.label(tr("UI_PRESS_CONFIRM"), 20, UiStyle.TEXT_DIM))
	visible = true
	size = Vector2.ZERO
	reset_size()
	position = (get_viewport_rect().size - size) * 0.5


func close() -> void:
	visible = false
