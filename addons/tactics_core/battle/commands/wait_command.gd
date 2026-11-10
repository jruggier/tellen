class_name WaitCommand
extends Command
## Ends a unit's action for this phase without doing anything else.

var unit_id: StringName


func _init(waiting_unit_id: StringName = &"") -> void:
	unit_id = waiting_unit_id


func get_type() -> StringName:
	return &"wait"


func can_execute(state: BattleState) -> bool:
	var unit: UnitState = state.get_unit(unit_id)
	if unit == null or not unit.is_ready():
		return false
	return state.current_faction() == null or state.current_faction().id == unit.faction_id


func execute(state: BattleState) -> void:
	var unit: UnitState = state.get_unit(unit_id)
	unit.has_moved = true
	unit.has_acted = true
	state.mark_changed()


func to_dict() -> Dictionary:
	return {"type": "wait", "unit": String(unit_id)}
