class_name MapEventRules
extends RefCounted
## Matching and firing [MapEvent]s (spec §8.6). Pure: changes only the
## battle state; dialogue is played by the caller from the returned outcome.


## What firing an event did, for presentation.
class Outcome:
	extends RefCounted
	var event: MapEvent
	var dialogue_id: StringName = &""
	var spawned: Array[StringName] = []
	var items_given: Array[ItemData] = []
	var items_lost: Array[ItemData] = []
	var objectives_added: Array[Objective] = []
	var recruited: StringName = &""


## Events in [param events] with [param trigger] that may fire now.
## [param context] keys: "unit", "other" (UnitState), "cell" (Vector2i).
static func matching(state: BattleState, events: Array[MapEvent], trigger: MapEvent.Trigger, context: Dictionary = {}) -> Array[MapEvent]:
	var result: Array[MapEvent] = []
	for event: MapEvent in events:
		if event == null or event.trigger != trigger or not available(state, event):
			continue
		if _matches(state, event, context):
			result.append(event)
	return result


## True if [param event] has not fired (or may repeat) and its flag is set.
static func available(state: BattleState, event: MapEvent) -> bool:
	if event.once and state.flags.get(_fired_key(event), false):
		return false
	return event.required_flag.is_empty() or DialogueRunner.is_truthy(get_flag(state, event.required_flag))


## Fires [param event]: marks it, applies its actions. [param context] as in [method matching].
static func fire(state: BattleState, event: MapEvent, context: Dictionary = {}) -> Outcome:
	var outcome := Outcome.new()
	outcome.event = event
	outcome.dialogue_id = event.dialogue_id
	state.flags[_fired_key(event)] = true
	for group: StringName in event.wake_groups:
		AIRules.wake_group(state, group)
	for flag: String in event.set_flags:
		set_flag(state, flag, true)
	var unit: UnitState = context.get("unit", null)
	for item: ItemData in event.give_items:
		if unit != null and unit.has_inventory_space(state.ruleset):
			unit.inventory.append(InventorySlot.of(item))
			outcome.items_given.append(item)
		else:
			outcome.items_lost.append(item)
	outcome.objectives_added = event.add_objectives.duplicate()
	for placement: UnitPlacement in event.spawn:
		if placement == null or state.unit_at(placement.cell) != null:
			continue
		var spawned: UnitState = UnitFactory.from_placement(state, placement)
		if spawned != null and state.add_unit(spawned):
			spawned.has_moved = true
			spawned.has_acted = true
			if state.ruleset.awakening_rule != null:
				state.ruleset.awakening_rule.on_unit_added(state, spawned)
			outcome.spawned.append(spawned.id)
	var other: UnitState = context.get("other", null)
	if event.recruit and unit != null and other != null:
		other.faction_id = unit.faction_id
		other.ai_profile = null
		other.has_moved = true
		other.has_acted = true
		outcome.recruited = other.id
	state.mark_changed()
	return outcome


## Reads a flag: [code]map.*[/code] from the map, others from the campaign.
static func get_flag(state: BattleState, flag: String) -> Variant:
	if flag.begins_with("map."):
		return state.flags.get(flag.trim_prefix("map."), null)
	return state.campaign.flags.get(flag, null) if state.campaign != null else null


static func set_flag(state: BattleState, flag: String, value: Variant) -> void:
	if flag.begins_with("map."):
		state.flags[flag.trim_prefix("map.")] = value
	elif state.campaign != null:
		state.campaign.flags[flag] = value


static func _matches(state: BattleState, event: MapEvent, context: Dictionary) -> bool:
	var unit: UnitState = context.get("unit", null)
	var other: UnitState = context.get("other", null)
	match event.trigger:
		MapEvent.Trigger.MAP_START, MapEvent.Trigger.MAP_END:
			return true
		MapEvent.Trigger.TURN:
			var faction: FactionData = state.current_faction()
			var wanted: StringName = event.faction_id if event.faction_id != &"" else Objective.player_faction_id(state)
			return state.turn == event.turn and faction != null and faction.id == wanted
		MapEvent.Trigger.REINFORCEMENT:
			return state.turn == event.turn
		MapEvent.Trigger.REGION:
			var wanted_faction: StringName = event.faction_id if event.faction_id != &"" else Objective.player_faction_id(state)
			return unit != null and unit.is_alive() and unit.faction_id == wanted_faction and event.region.has_point(unit.cell)
		MapEvent.Trigger.UNIT_DEFEATED:
			var target: UnitState = state.get_unit(event.unit_id)
			return target != null and not target.is_alive()
		MapEvent.Trigger.BATTLE_QUOTE:
			if unit == null or other == null:
				return false
			return _quote_pair(event, unit, other) or _quote_pair(event, other, unit)
		MapEvent.Trigger.TALK:
			return unit != null and other != null and unit.id == event.unit_id and other.id == event.other_unit_id
		MapEvent.Trigger.VISIT:
			return unit != null and unit.cell == event.cell
	return false


static func _quote_pair(event: MapEvent, first: UnitState, second: UnitState) -> bool:
	var first_ok: bool = first.id == event.unit_id if event.unit_id != &"" else first.is_boss
	var second_ok: bool = event.other_unit_id == &"" or second.id == event.other_unit_id
	return first_ok and second_ok


static func _fired_key(event: MapEvent) -> String:
	return "event_fired:%s" % event.id
