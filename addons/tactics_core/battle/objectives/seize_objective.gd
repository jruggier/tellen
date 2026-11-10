@tool
class_name SeizeObjective
extends Objective
## The protagonist seizes [member cell] (Seize action while standing on it).

const FLAG_SEIZED: String = "seized"

@export var cell: Vector2i = Vector2i.ZERO


func is_complete(state: BattleState) -> bool:
	return state.flags.get(FLAG_SEIZED, Vector2i(-9999, -9999)) == cell


func default_description() -> String:
	return tr("OBJECTIVE_SEIZE") % [cell.x, cell.y]
