@tool
class_name SurviveObjective
extends Objective
## Last through [member turns] full turns (won when turn turns + 1 begins).

@export_range(1, 99) var turns: int = 5


func is_complete(state: BattleState) -> bool:
	return state.turn > turns


func describe() -> String:
	return tr("OBJECTIVE_SURVIVE") % turns


func progress(state: BattleState) -> String:
	return tr("OBJECTIVE_TURNS_PROGRESS") % [mini(state.turn, turns), turns]
