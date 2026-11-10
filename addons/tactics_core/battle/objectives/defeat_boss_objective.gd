@tool
class_name DefeatBossObjective
extends Objective
## Defeat the unit with [member unit_id], or every boss when empty.

@export var unit_id: StringName = &""


func is_complete(state: BattleState) -> bool:
	var found: bool = false
	for unit: UnitState in state.all_units():
		var matches: bool = unit.id == unit_id if unit_id != &"" else unit.is_boss
		if matches:
			found = true
			if unit.is_alive():
				return false
	return found


func describe() -> String:
	return tr("OBJECTIVE_DEFEAT_BOSS")
