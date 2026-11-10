class_name ClassChangeCommand
extends Command
## Changes a unit's class (see [ClassChangeRules]). Ends the unit's action.

var unit_id: StringName
var class_id: StringName
## Filled on execute: stat changes.
var delta: StatBlock


func _init(changing_unit: StringName = &"", new_class_id: StringName = &"") -> void:
	unit_id = changing_unit
	class_id = new_class_id


func get_type() -> StringName:
	return &"class_change"


func can_execute(state: BattleState) -> bool:
	var unit: UnitState = state.get_unit(unit_id)
	if unit == null or not unit.is_ready():
		return false
	if state.current_faction() != null and state.current_faction().id != unit.faction_id:
		return false
	return _target_class(state, unit) != null


func execute(state: BattleState) -> void:
	var unit: UnitState = state.get_unit(unit_id)
	delta = ClassChangeRules.apply(state, unit, _target_class(state, unit))
	unit.has_moved = true
	unit.has_acted = true
	state.mark_changed()


func to_dict() -> Dictionary:
	return {"type": "class_change", "unit": String(unit_id), "class": String(class_id)}


func _target_class(state: BattleState, unit: UnitState) -> ClassData:
	for class_data: ClassData in ClassChangeRules.eligible_classes(state, unit):
		if class_data.id == class_id:
			return class_data
	return null
