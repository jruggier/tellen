class_name AwakenCommand
extends Command
## Awakens a unit (spec §9.5). A free action: the unit can still act, but
## its move is locked in.

var unit_id: StringName


func _init(awakening_unit: StringName = &"") -> void:
	unit_id = awakening_unit


func get_type() -> StringName:
	return &"awaken"


func can_execute(state: BattleState) -> bool:
	var unit: UnitState = state.get_unit(unit_id)
	var rule: AwakeningRule = state.ruleset.awakening_rule
	if unit == null or rule == null or not unit.is_ready():
		return false
	if state.current_faction() != null and state.current_faction().id != unit.faction_id:
		return false
	return rule.can_awaken(state, unit)


func execute(state: BattleState) -> void:
	state.ruleset.awakening_rule.awaken(state, state.get_unit(unit_id))
	state.mark_changed()


func to_dict() -> Dictionary:
	return {"type": "awaken", "unit": String(unit_id)}
