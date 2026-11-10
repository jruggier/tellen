extends GutTest
## Chapter maps built from the template: ch00 (tutorial) and ch01 (Bridge Deal).

const DATA: String = "res://game/data/"


func _setup(path: String, campaign_flags: Dictionary = {}) -> BattleController:
	var map: BattleMap = (load(path) as PackedScene).instantiate() as BattleMap
	add_child_autofree(map)
	var controller := BattleController.new()
	add_child_autofree(controller)
	var roster: Array[UnitData] = (load(DATA + "units/test_roster.tres") as UnitRoster).units
	controller.setup(map, load("res://game/rules/crossroads_ruleset.tres") as Ruleset, 1, &"normal", roster)
	controller.state.campaign.flags = campaign_flags
	return controller


func test_ch00_tutorial_setup() -> void:
	var state: BattleState = _setup("res://game/maps/ch00_ruined_crossroads.tscn").state
	var players: Array[String] = []
	for unit: UnitState in state.units_of(&"player"):
		players.append(String(unit.id))
	players.sort()
	assert_eq(players, ["gid", "sable", "tellen"] as Array[String], "the three forced heroes")
	assert_eq(state.units_of(&"enemy").size(), 5)
	var thug: UnitState = state.get_unit(&"slow_thug")
	var tellen: UnitState = state.get_unit(&"tellen")
	var forecast: CombatForecast = CombatForecast.build(state, tellen, thug, Vector2i(10, 6))
	assert_gt(forecast.attacker.follow_up_percent, 0, "the slow thug exists to show off follow-ups")
	assert_true(CombatForecast.build(state, tellen, state.get_unit(&"first_brigand"), Vector2i(7, 7)).stagger_on_hit, "sword staggers the first axe")
	assert_true(state.get_unit(&"bandit_chief").is_boss)


func test_ch01_objective_and_loot() -> void:
	var controller: BattleController = _setup("res://game/maps/ch01_the_bridge_deal.tscn")
	var state: BattleState = controller.state
	assert_eq(state.units_of(&"player").size(), 5, "deploy count 5")
	assert_not_null(state.get_unit(&"tellen"), "Tellen is forced")
	var chest: MapEvent = null
	for event: MapEvent in state.map_events:
		if event.id == &"camp_chest":
			chest = event
	assert_not_null(chest)
	var loot: Array[StringName] = []
	for item: ItemData in chest.give_items:
		loot.append(item.id)
	assert_eq(loot, [&"stolen_crate", &"steel_sword", &"elixir"] as Array[StringName])
	assert_true(state.get_unit(&"gate_captain").movement_type_id() == &"heavy", "the gate captain can't be Staggered")


func test_ch01_toll_choice_branches() -> void:
	var walked: BattleState = _setup("res://game/maps/ch01_the_bridge_deal.tscn").state
	TurnManager.start_battle(walked)
	assert_eq(MapEventRules.matching(walked, walked.map_events, MapEvent.Trigger.TURN).size(), 1, "walked away: the ambush fires")
	var paid: BattleState = _setup("res://game/maps/ch01_the_bridge_deal.tscn", {"paid_toll": true}).state
	TurnManager.start_battle(paid)
	assert_eq(MapEventRules.matching(paid, paid.map_events, MapEvent.Trigger.TURN).size(), 0, "paid: no ambush")
