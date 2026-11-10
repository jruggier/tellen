class_name EventCommands
extends RefCounted
## Commands that fire map events: [code]EventCommands.Trigger[/code]
## (automatic triggers), [code]EventCommands.Talk[/code] and
## [code]EventCommands.Visit[/code] (action-menu entries that end the action).


## Fires one event (map start, turn, region, defeat, quote, map end...).
class Trigger:
	extends Command
	var event: MapEvent
	var context: Dictionary = {}
	var outcome: MapEventRules.Outcome

	func _init(fired_event: MapEvent = null, fire_context: Dictionary = {}) -> void:
		event = fired_event
		context = fire_context

	func get_type() -> StringName:
		return &"event"

	func can_execute(state: BattleState) -> bool:
		return event != null and MapEventRules.available(state, event)

	func execute(state: BattleState) -> void:
		outcome = MapEventRules.fire(state, event, context)

	func to_dict() -> Dictionary:
		return {"type": "event", "event": String(event.id) if event != null else ""}


## Talk: a unit speaks to an adjacent unit with a matching TALK event.
class Talk:
	extends Command
	var unit_id: StringName
	var target_id: StringName
	var events: Array[MapEvent] = []
	var outcome: MapEventRules.Outcome

	func _init(talker: StringName = &"", listener: StringName = &"", map_events: Array[MapEvent] = []) -> void:
		unit_id = talker
		target_id = listener
		events = map_events

	func get_type() -> StringName:
		return &"talk"

	## Units [param unit] can Talk to from where it stands.
	static func partners(state: BattleState, unit: UnitState, map_events: Array[MapEvent]) -> Array[UnitState]:
		var result: Array[UnitState] = []
		for neighbor: Vector2i in state.grid.neighbors(unit.cell):
			var other: UnitState = state.unit_at(neighbor)
			if other != null and not MapEventRules.matching(state, map_events, MapEvent.Trigger.TALK, {"unit": unit, "other": other}).is_empty():
				result.append(other)
		return result

	func can_execute(state: BattleState) -> bool:
		var unit: UnitState = state.get_unit(unit_id)
		if unit == null or not unit.is_ready():
			return false
		if state.current_faction() != null and state.current_faction().id != unit.faction_id:
			return false
		return partners(state, unit, events).has(state.get_unit(target_id))

	func execute(state: BattleState) -> void:
		var unit: UnitState = state.get_unit(unit_id)
		var other: UnitState = state.get_unit(target_id)
		var context: Dictionary = {"unit": unit, "other": other}
		outcome = MapEventRules.fire(state, MapEventRules.matching(state, events, MapEvent.Trigger.TALK, context)[0], context)
		unit.has_moved = true
		unit.has_acted = true

	func to_dict() -> Dictionary:
		return {"type": "talk", "unit": String(unit_id), "target": String(target_id)}


## Visit: a unit uses the village / chest event on its tile.
class Visit:
	extends Command
	var unit_id: StringName
	var events: Array[MapEvent] = []
	var outcome: MapEventRules.Outcome

	func _init(visitor: StringName = &"", map_events: Array[MapEvent] = []) -> void:
		unit_id = visitor
		events = map_events

	func get_type() -> StringName:
		return &"visit"

	## The VISIT event available on [param unit]'s tile, or null.
	static func event_for(state: BattleState, unit: UnitState, map_events: Array[MapEvent]) -> MapEvent:
		var found: Array[MapEvent] = MapEventRules.matching(state, map_events, MapEvent.Trigger.VISIT, {"unit": unit})
		return found[0] if not found.is_empty() else null

	func can_execute(state: BattleState) -> bool:
		var unit: UnitState = state.get_unit(unit_id)
		if unit == null or not unit.is_ready():
			return false
		if state.current_faction() != null and state.current_faction().id != unit.faction_id:
			return false
		return event_for(state, unit, events) != null

	func execute(state: BattleState) -> void:
		var unit: UnitState = state.get_unit(unit_id)
		outcome = MapEventRules.fire(state, event_for(state, unit, events), {"unit": unit})
		unit.has_moved = true
		unit.has_acted = true

	func to_dict() -> Dictionary:
		return {"type": "visit", "unit": String(unit_id)}
