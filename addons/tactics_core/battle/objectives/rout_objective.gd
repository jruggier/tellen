@tool
class_name RoutObjective
extends Objective
## Defeat every hostile unit, including reinforcements still to arrive.


func is_complete(state: BattleState) -> bool:
	if not hostile_units(state).is_empty():
		return false
	var player: StringName = player_faction_id(state)
	for arrival: Dictionary in state.pending_arrivals:
		if not state.are_allied(StringName(arrival["faction"]), player):
			return false
	return true


func default_description() -> String:
	return tr("OBJECTIVE_ROUT")


func progress(state: BattleState) -> String:
	return tr("OBJECTIVE_ENEMIES_LEFT") % hostile_units(state).size()
