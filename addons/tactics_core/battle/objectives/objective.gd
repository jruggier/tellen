@tool
class_name Objective
extends Resource
## A victory objective (spec §8.3). A map lists one or more; the battle is
## won when all are complete. Subclasses implement [method is_complete] and
## may implement [method is_failed] (e.g. a defended tile was lost).
##
## Objectives judge from the human faction's point of view: "hostile" means
## not allied with the first human-controlled faction.


## True once the objective is achieved.
func is_complete(_state: BattleState) -> bool:
	return false


## True if the objective can no longer be achieved (counts as defeat).
func is_failed(_state: BattleState) -> bool:
	return false


## Optional translation key that replaces the generic description
## (e.g. "Seize the toll camp" instead of "Seize the tile at 26 / 8").
@export var label: String = ""


## Player-facing description (localized): [member label] if set, else the
## generic text from [method default_description].
func describe() -> String:
	return tr(label) if not label.is_empty() else default_description()


## Generic description for this objective type.
func default_description() -> String:
	return ""


## Optional progress text, e.g. "3 / 5 turns".
func progress(_state: BattleState) -> String:
	return ""


## Problems with this objective's settings (empty when valid).
func validate() -> PackedStringArray:
	return PackedStringArray()


## The human faction's id (the side objectives are judged for).
static func player_faction_id(state: BattleState) -> StringName:
	var human: FactionData = state.human_faction()
	return human.id if human != null else &"player"


## Living units hostile to the human faction.
static func hostile_units(state: BattleState) -> Array[UnitState]:
	var result: Array[UnitState] = []
	var player: StringName = player_faction_id(state)
	for unit: UnitState in state.all_units():
		if unit.is_alive() and not unit.escaped and not state.are_allied(unit.faction_id, player):
			result.append(unit)
	return result
