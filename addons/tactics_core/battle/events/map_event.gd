@tool
class_name MapEvent
extends Resource
## Something that happens on a map when its trigger fires (spec §8.6):
## play a dialogue scene and/or change the battle.
##
## Unit ids refer to battle unit ids (named units use their unit id, e.g.
## [code]tellen[/code]). Flag names follow dialogue rules: [code]map.*[/code]
## flags belong to the map, others to the campaign.

enum Trigger {
	## Before the first phase.
	MAP_START,
	## On victory, before the result screen.
	MAP_END,
	## At the start of [member faction_id]'s phase on [member turn].
	TURN,
	## A unit of [member faction_id] stops inside [member region].
	REGION,
	## [member unit_id] is defeated.
	UNIT_DEFEATED,
	## Before a combat between [member unit_id] (empty = any boss) and
	## [member other_unit_id] (empty = anyone).
	BATTLE_QUOTE,
	## [member unit_id] uses Talk on [member other_unit_id].
	TALK,
	## A unit uses Visit on [member cell] (village, chest...).
	VISIT,
	## Reinforcements arrive on [member turn].
	REINFORCEMENT,
}

## Unique id (fired events are remembered by id).
@export var id: StringName = &""
@export var trigger: Trigger = Trigger.MAP_START
## Fire only once.
@export var once: bool = true
## Fire only while this flag is set; "!flag" = only while it is not set
## (empty = always).
@export var required_flag: String = ""

@export_group("Trigger settings")
## TURN / REINFORCEMENT: the turn.
@export_range(1, 999) var turn: int = 1
## TURN / REGION: the faction (empty = the human faction).
@export var faction_id: StringName = &""
## REGION: the cells.
@export var region: Rect2i = Rect2i(0, 0, 1, 1)
## VISIT: the tile.
@export var cell: Vector2i = Vector2i.ZERO
## UNIT_DEFEATED / BATTLE_QUOTE / TALK: the main unit.
@export var unit_id: StringName = &""
## BATTLE_QUOTE / TALK: the other unit.
@export var other_unit_id: StringName = &""

@export_group("Actions")
## Dialogue scene to play.
@export var dialogue_id: StringName = &""
## Items given to the unit that triggered the event (visitor, talker).
@export var give_items: Array[ItemData] = []
## AI groups to wake.
@export var wake_groups: Array[StringName] = []
## Flags set to true.
@export var set_flags: Array[String] = []
## Objectives added to the map.
@export var add_objectives: Array[Objective] = []
## Units that appear (cannot act on the phase they appear).
@export var spawn: Array[UnitPlacement] = []
## TALK: the other unit joins the talker's faction.
@export var recruit: bool = false
## VISIT: translation key for the action-menu entry (empty = "Visit").
@export var action_label: String = ""


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("MapEvent with trigger %s has no id" % Trigger.keys()[trigger])
	if trigger == Trigger.TALK and (unit_id == &"" or other_unit_id == &""):
		problems.append("MapEvent '%s': TALK needs unit_id and other_unit_id" % id)
	if trigger == Trigger.UNIT_DEFEATED and unit_id == &"":
		problems.append("MapEvent '%s': UNIT_DEFEATED needs unit_id" % id)
	return problems
