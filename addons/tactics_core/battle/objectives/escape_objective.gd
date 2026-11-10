@tool
class_name EscapeObjective
extends Objective
## Get [member count] units off the map through any of [member cells]
## (Escape action while standing on one).

@export var cells: Array[Vector2i] = []
@export_range(1, 99) var count: int = 1


func is_complete(state: BattleState) -> bool:
	return escaped_count(state) >= count


func escaped_count(state: BattleState) -> int:
	var total: int = 0
	for unit: UnitState in state.all_units():
		if unit.escaped:
			total += 1
	return total


func describe() -> String:
	return tr("OBJECTIVE_ESCAPE") % count


func progress(state: BattleState) -> String:
	return "%d / %d" % [escaped_count(state), count]


func validate() -> PackedStringArray:
	return PackedStringArray(["EscapeObjective has no escape cells"]) if cells.is_empty() else PackedStringArray()
