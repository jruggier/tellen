extends GutTest
## Map events (§8.6): triggers, once/flags, actions, Talk and Visit.

const DATA: String = "res://game/data/"


func _battle() -> BattleState:
	var battle: BattleState = BattleFixtures.state([".....", ".....", "....."])
	var tellen: UnitState = UnitState.from_unit_data(&"tellen", load(DATA + "units/tellen.tres") as UnitData, battle.ruleset, &"player", Vector2i(0, 0))
	battle.add_unit(tellen)
	BattleFixtures.add(battle, &"foe", "hexcaller", &"enemy", Vector2i(1, 0), ["flux"])
	return battle


func _event(trigger: MapEvent.Trigger, event_id: String = "e") -> MapEvent:
	var event := MapEvent.new()
	event.id = StringName(event_id)
	event.trigger = trigger
	return event


func _events(list: Array) -> Array[MapEvent]:
	var result: Array[MapEvent] = []
	result.assign(list)
	return result


func test_once_and_required_flag() -> void:
	var battle: BattleState = _battle()
	var event: MapEvent = _event(MapEvent.Trigger.MAP_START)
	event.required_flag = "map.ready"
	var events: Array[MapEvent] = _events([event])
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.MAP_START).size(), 0, "flag not set")
	battle.flags["ready"] = true
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.MAP_START).size(), 1)
	MapEventRules.fire(battle, event)
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.MAP_START).size(), 0, "once")
	event.once = false
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.MAP_START).size(), 1, "repeatable")


func test_turn_trigger_checks_turn_and_faction() -> void:
	var battle: BattleState = _battle()
	var event: MapEvent = _event(MapEvent.Trigger.TURN)
	event.turn = 2
	var events: Array[MapEvent] = _events([event])
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.TURN).size(), 0)
	battle.turn = 2
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.TURN).size(), 1, "player phase by default")
	battle.phase_index = 1
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.TURN).size(), 0)


func test_region_and_defeat_triggers() -> void:
	var battle: BattleState = _battle()
	var region: MapEvent = _event(MapEvent.Trigger.REGION, "r")
	region.region = Rect2i(3, 0, 2, 3)
	var defeat: MapEvent = _event(MapEvent.Trigger.UNIT_DEFEATED, "d")
	defeat.unit_id = &"foe"
	var events: Array[MapEvent] = _events([region, defeat])
	var tellen: UnitState = battle.get_unit(&"tellen")
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.REGION, {"unit": tellen}).size(), 0)
	battle.move_unit(&"tellen", Vector2i(3, 1))
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.REGION, {"unit": tellen}).size(), 1)
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.REGION, {"unit": battle.get_unit(&"foe")}).size(), 0, "player faction only")
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.UNIT_DEFEATED).size(), 0)
	DefeatRules.apply(battle, battle.get_unit(&"foe"), null)
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.UNIT_DEFEATED).size(), 1)


func test_battle_quote_matches_either_order_and_any_boss() -> void:
	var battle: BattleState = _battle()
	var quote: MapEvent = _event(MapEvent.Trigger.BATTLE_QUOTE)
	var events: Array[MapEvent] = _events([quote])
	var tellen: UnitState = battle.get_unit(&"tellen")
	var foe: UnitState = battle.get_unit(&"foe")
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.BATTLE_QUOTE, {"unit": tellen, "other": foe}).size(), 0, "no boss")
	foe.is_boss = true
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.BATTLE_QUOTE, {"unit": tellen, "other": foe}).size(), 1, "boss defending")
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.BATTLE_QUOTE, {"unit": foe, "other": tellen}).size(), 1, "boss attacking")
	quote.other_unit_id = &"sable"
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.BATTLE_QUOTE, {"unit": tellen, "other": foe}).size(), 0, "specific pair only")


func test_actions() -> void:
	var battle: BattleState = _battle()
	var sleeper: UnitState = battle.get_unit(&"foe")
	sleeper.ai_group = &"camp"
	var event: MapEvent = _event(MapEvent.Trigger.MAP_START)
	event.wake_groups = [&"camp"]
	event.set_flags = ["map.alarm", "met_elder"]
	event.give_items = _items(["items/elixir"])
	event.add_objectives = [SurviveObjective.new()]
	var reinforcement := UnitPlacement.new()
	reinforcement.class_data = load(DATA + "classes/brigand.tres") as ClassData
	reinforcement.cell = Vector2i(4, 2)
	event.spawn = [reinforcement]
	var tellen: UnitState = battle.get_unit(&"tellen")
	var outcome: MapEventRules.Outcome = MapEventRules.fire(battle, event, {"unit": tellen})
	assert_true(sleeper.ai_awake)
	assert_eq(battle.flags["alarm"], true, "map flag")
	assert_eq(battle.campaign.flags["met_elder"], true, "campaign flag")
	assert_eq(tellen.inventory.back().item.id, &"elixir")
	assert_eq(outcome.objectives_added.size(), 1)
	assert_eq(outcome.spawned.size(), 1)
	assert_false(battle.get_unit(outcome.spawned[0]).is_ready(), "spawned units wait a phase")


func _items(paths: Array[String]) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for path: String in paths:
		result.append(load(DATA + path + ".tres") as ItemData)
	return result


func test_talk_recruits() -> void:
	var battle: BattleState = _battle()
	var talk: MapEvent = _event(MapEvent.Trigger.TALK)
	talk.unit_id = &"tellen"
	talk.other_unit_id = &"foe"
	talk.recruit = true
	var events: Array[MapEvent] = _events([talk])
	var tellen: UnitState = battle.get_unit(&"tellen")
	assert_eq(EventCommands.Talk.partners(battle, tellen, events).size(), 1)
	var command := EventCommands.Talk.new(&"tellen", &"foe", events)
	assert_true(command.can_execute(battle))
	command.execute(battle)
	assert_eq(battle.get_unit(&"foe").faction_id, &"player", "recruited")
	assert_eq(command.outcome.recruited, &"foe")
	assert_true(tellen.has_acted, "talking ends the action")
	assert_false(EventCommands.Talk.new(&"tellen", &"foe", events).can_execute(battle), "once")


func test_visit() -> void:
	var battle: BattleState = _battle()
	var village: MapEvent = _event(MapEvent.Trigger.VISIT)
	village.cell = Vector2i(2, 2)
	village.give_items = _items(["items/vulnerary"])
	var events: Array[MapEvent] = _events([village])
	assert_false(EventCommands.Visit.new(&"tellen", events).can_execute(battle), "not on the tile")
	battle.move_unit(&"tellen", Vector2i(2, 2))
	var command := EventCommands.Visit.new(&"tellen", events)
	assert_true(command.can_execute(battle))
	command.execute(battle)
	assert_eq(command.outcome.items_given.size(), 1)
	assert_true(battle.get_unit(&"tellen").has_acted)


func test_validation() -> void:
	var event := MapEvent.new()
	event.trigger = MapEvent.Trigger.TALK
	assert_eq(event.validate().size(), 2, "no id; talk needs both units")
