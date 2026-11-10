@tool
class_name DefendTileObjective
extends Objective
## Keep hostile units off [member cell] through [member turns] turns.
## A hostile unit standing on the tile fails the objective.

@export var cell: Vector2i = Vector2i.ZERO
@export_range(1, 99) var turns: int = 5


func is_complete(state: BattleState) -> bool:
	return state.turn > turns and not is_failed(state)


func is_failed(state: BattleState) -> bool:
	var occupant: UnitState = state.unit_at(cell)
	return occupant != null and not state.are_allied(occupant.faction_id, player_faction_id(state))


func describe() -> String:
	return tr("OBJECTIVE_DEFEND") % [cell.x, cell.y, turns]


func progress(state: BattleState) -> String:
	return tr("OBJECTIVE_TURNS_PROGRESS") % [mini(state.turn, turns), turns]
