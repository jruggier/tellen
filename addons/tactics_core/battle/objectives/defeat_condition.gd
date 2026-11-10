@tool
class_name DefeatCondition
extends Resource
## A way to lose the battle (spec §8.3).

enum Kind {
	## A protagonist (is_lord) is defeated.
	LORD_DEFEATED,
	## Every unit of the human faction is gone.
	ALL_UNITS_DEFEATED,
	## The unit with [member unit_id] (e.g. a protected NPC) is defeated.
	UNIT_DEFEATED,
	## Turn [member turn_limit] + 1 begins before victory.
	TURN_LIMIT,
}

@export var kind: Kind = Kind.LORD_DEFEATED
@export var unit_id: StringName = &""
@export_range(1, 99) var turn_limit: int = 10


## True if this condition has been met.
func is_met(state: BattleState) -> bool:
	match kind:
		Kind.LORD_DEFEATED:
			for unit: UnitState in state.all_units():
				if unit.is_lord and not unit.is_alive():
					return true
			return false
		Kind.ALL_UNITS_DEFEATED:
			var player: StringName = Objective.player_faction_id(state)
			for unit: UnitState in state.all_units():
				if unit.faction_id == player and (unit.is_alive() or unit.escaped):
					return false
			return true
		Kind.UNIT_DEFEATED:
			var target: UnitState = state.get_unit(unit_id)
			return target != null and not target.is_alive()
		Kind.TURN_LIMIT:
			return state.turn > turn_limit
	return false


func describe() -> String:
	match kind:
		Kind.LORD_DEFEATED:
			return tr("DEFEAT_LORD")
		Kind.ALL_UNITS_DEFEATED:
			return tr("DEFEAT_ALL_UNITS")
		Kind.UNIT_DEFEATED:
			return tr("DEFEAT_UNIT") % unit_id
		Kind.TURN_LIMIT:
			return tr("DEFEAT_TURN_LIMIT") % turn_limit
	return ""


static func make(condition_kind: Kind) -> DefeatCondition:
	var condition := DefeatCondition.new()
	condition.kind = condition_kind
	return condition
