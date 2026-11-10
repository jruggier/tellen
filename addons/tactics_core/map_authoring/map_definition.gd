@tool
class_name MapDefinition
extends Resource
## Everything about a map that isn't placed on it (spec §12.3): name,
## factions, objectives, defeat conditions, deployment, story scenes,
## events, music and tuning notes. Units, spawn slots, reinforcements,
## objective tiles, regions and villages are placed as markers instead.

## Stable id (saves, events). Defaults to the scene file name when empty.
@export var map_id: StringName = &""
## Translation key or plain text for the map's title.
@export var display_name: String = ""
## Chapter id for campaign flow (e.g. "ch01").
@export var chapter_id: StringName = &""
## Factions in phase order (first is the player).
@export var factions: Array[FactionData] = []

@export_group("Victory and defeat")
## All must be met to win (empty = Rout). Objective tile markers add more.
@export var objectives: Array[Objective] = []
## Ways to lose (empty = protagonist defeated, or all units defeated).
@export var defeat_conditions: Array[DefeatCondition] = []
## Lose when this turn ends (0 = no limit).
@export_range(0, 99) var turn_limit: int = 0

@export_group("Deployment")
## Units the player brings (0 = one per player spawn marker).
@export_range(0, 50) var deploy_count: int = 0
## Units that must deploy (placed on spawn slots marked for them, or the first free slots).
@export var forced_units: Array[UnitData] = []

@export_group("Story")
## Scene played before the battle (MAP_START).
@export var pre_battle_dialogue: StringName = &""
## Scene played on victory, before the results (MAP_END).
@export var post_battle_dialogue: StringName = &""
## Other events (turns, defeats, quotes, talks...). Regions and villages are markers.
@export var events: Array[MapEvent] = []

@export_group("Presentation and tuning")
## Battle music id.
@export var music: StringName = &""
## Suggested level, for tuning notes only.
@export_range(1, 99) var recommended_level: int = 1
## Free-form design notes.
@export_multiline var notes: String = ""


## Objectives including the turn-limit defeat condition.
func all_defeat_conditions() -> Array[DefeatCondition]:
	var result: Array[DefeatCondition] = defeat_conditions.duplicate()
	if turn_limit > 0:
		var limit := DefeatCondition.make(DefeatCondition.Kind.TURN_LIMIT)
		limit.turn_limit = turn_limit
		if result.is_empty():
			result.append(DefeatCondition.make(DefeatCondition.Kind.LORD_DEFEATED))
			result.append(DefeatCondition.make(DefeatCondition.Kind.ALL_UNITS_DEFEATED))
		result.append(limit)
	return result


## Story events generated from the pre/post-battle dialogue fields.
func story_events() -> Array[MapEvent]:
	var result: Array[MapEvent] = []
	if pre_battle_dialogue != &"":
		var start := MapEvent.new()
		start.id = &"pre_battle"
		start.trigger = MapEvent.Trigger.MAP_START
		start.dialogue_id = pre_battle_dialogue
		result.append(start)
	if post_battle_dialogue != &"":
		var finish := MapEvent.new()
		finish.id = &"post_battle"
		finish.trigger = MapEvent.Trigger.MAP_END
		finish.dialogue_id = post_battle_dialogue
		result.append(finish)
	return result
