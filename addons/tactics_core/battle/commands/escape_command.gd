class_name EscapeCommand
extends Command
## A unit on an escape tile leaves the map (Escape objective).

var unit_id: StringName
var objectives: Array[Objective] = []


func _init(escaping_unit: StringName = &"", map_objectives: Array[Objective] = []) -> void:
	unit_id = escaping_unit
	objectives = map_objectives


func get_type() -> StringName:
	return &"escape"


func can_execute(state: BattleState) -> bool:
	var unit: UnitState = state.get_unit(unit_id)
	if unit == null or not unit.is_ready():
		return false
	if state.current_faction() != null and state.current_faction().id != unit.faction_id:
		return false
	for objective: Objective in objectives:
		if objective is EscapeObjective and (objective as EscapeObjective).cells.has(unit.cell):
			return true
	return false


func execute(state: BattleState) -> void:
	var unit: UnitState = state.get_unit(unit_id)
	unit.escaped = true
	unit.has_moved = true
	unit.has_acted = true
	state.remove_from_map(unit_id)


func to_dict() -> Dictionary:
	return {"type": "escape", "unit": String(unit_id)}
