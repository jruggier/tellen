class_name SeizeCommand
extends Command
## The protagonist seizes the tile it stands on (Seize objective). Ends its action.

var unit_id: StringName
var objectives: Array[Objective] = []


func _init(seizing_unit: StringName = &"", map_objectives: Array[Objective] = []) -> void:
	unit_id = seizing_unit
	objectives = map_objectives


func get_type() -> StringName:
	return &"seize"


func can_execute(state: BattleState) -> bool:
	var unit: UnitState = state.get_unit(unit_id)
	if unit == null or not unit.is_ready() or not unit.is_lord:
		return false
	if state.current_faction() != null and state.current_faction().id != unit.faction_id:
		return false
	for objective: Objective in objectives:
		if objective is SeizeObjective and (objective as SeizeObjective).cell == unit.cell:
			return true
	return false


func execute(state: BattleState) -> void:
	var unit: UnitState = state.get_unit(unit_id)
	state.flags[SeizeObjective.FLAG_SEIZED] = unit.cell
	unit.has_moved = true
	unit.has_acted = true
	state.mark_changed()


func to_dict() -> Dictionary:
	return {"type": "seize", "unit": String(unit_id)}
