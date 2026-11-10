extends GutTest
## M3 model: attack/heal/item/equip/trade commands, Stagger lifecycle,
## defeat and retreat, drops, EXP, level-ups and proficiency.

const DATA: String = "res://game/data/"


func _named(battle: BattleState, unit_id: String, faction: StringName, cell: Vector2i) -> UnitState:
	var unit: UnitState = UnitState.from_unit_data(StringName(unit_id), load(DATA + "units/%s.tres" % unit_id) as UnitData, battle.ruleset, faction, cell)
	battle.add_unit(unit)
	return unit


func _item(path: String) -> ItemData:
	return load(DATA + path + ".tres") as ItemData


# Forecast = resolver --------------------------------------------------------------

func test_forecast_build_matches_attack_results() -> void:
	for seed: int in 60:
		var battle: BattleState = BattleFixtures.state(["....", "...."])
		battle.rng = SeededRng.new(seed)
		var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
		var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"], 3)
		foe.current_hp = 99
		foe.stats.set_value(&"hp", 99)
		var forecast: CombatForecast = CombatForecast.build(battle, tellen, foe, tellen.cell)
		var attack := AttackCommand.new(&"tellen", &"foe", 0)
		assert_true(attack.can_execute(battle))
		attack.execute(battle)
		for strike: Strike in attack.result.strikes:
			if not strike.hit:
				continue
			var side: CombatForecast.SideForecast = forecast.attacker if strike.actor == Strike.Role.ATTACKER else forecast.defender
			var base: int = side.follow_up_damage if strike.kind == Strike.Kind.FOLLOW_UP else side.damage
			var expected: int = battle.ruleset.combat_rules.crit_damage(base) if strike.crit else base
			if strike.damage != mini(expected, strike.target_hp_after + strike.damage):
				fail_test("seed %d: strike %s dealt %d, forecast %d" % [seed, strike.to_dict(), strike.damage, expected])
				return
	pass_test("forecast matches resolved attacks")


func test_forecast_uses_destination_terrain() -> void:
	# foe at (1,1) is adjacent to both the forest at (1,0) and the plains at (0,1)
	var battle: BattleState = BattleFixtures.state([".F", ".."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 1), ["iron_axe"])
	var on_plains: CombatForecast = CombatForecast.build(battle, tellen, foe, Vector2i(0, 1))
	var in_forest: CombatForecast = CombatForecast.build(battle, tellen, foe, Vector2i(1, 0))
	assert_gt(on_plains.defender.hit, 0)
	assert_eq(in_forest.defender.hit, maxi(0, on_plains.defender.hit - 20), "forest gives +20 avoid")


# Attack ------------------------------------------------------------------------------

func test_attack_validation() -> void:
	var battle: BattleState = BattleFixtures.state(["....."])
	_named(battle, "tellen", &"player", Vector2i(0, 0))
	_named(battle, "gid", &"player", Vector2i(1, 0))
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(3, 0), ["iron_axe"])
	assert_false(AttackCommand.new(&"tellen", &"foe", 0).can_execute(battle), "out of range")
	assert_false(AttackCommand.new(&"tellen", &"gid", 0).can_execute(battle), "cannot attack allies")
	assert_false(AttackCommand.new(&"tellen", &"foe", 1).can_execute(battle), "slot 1 is a vulnerary")


func test_attack_with_second_weapon_equips_it() -> void:
	var battle: BattleState = BattleFixtures.state(["....."])
	var gid: UnitState = _named(battle, "gid", &"player", Vector2i(1, 0))
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(3, 0), ["iron_axe"])
	var attack := AttackCommand.new(&"gid", &"foe", 1)
	assert_true(attack.can_execute(battle), "hand axe hits at range 2")
	attack.execute(battle)
	assert_eq(gid.equipped_weapon().id, &"hand_axe")
	assert_true(gid.has_acted)


func test_attack_applies_hp_and_stagger_lifecycle() -> void:
	var battle: BattleState = BattleFixtures.state(["...."])
	battle.rng = ScriptedRng.new([0, 99, 99, 99, 99])  # attacker hits (no crit), counter misses, rest miss
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"], 2)
	var attack := AttackCommand.new(&"tellen", &"foe", 0)
	attack.execute(battle)
	assert_eq(foe.current_hp, attack.result.defender_hp_after)
	assert_true(foe.is_staggered(), "sword hit staggers the axe user")
	assert_eq(foe.stagger_combats, 1)
	# The Staggered brigand's next combat uses it up
	battle.phase_index = 1
	var counter := AttackCommand.new(&"foe", &"tellen", 0)
	battle.rng = SeededRng.new(1)
	assert_true(counter.can_execute(battle))
	counter.execute(battle)
	assert_false(foe.is_staggered(), "cleared after its next combat")
	# Phase end clears any Stagger
	foe.stagger_combats = 1
	battle.clear_staggers()
	assert_false(foe.is_staggered())


func test_staggered_unit_participant_cannot_follow_up() -> void:
	var battle: BattleState = BattleFixtures.state(["..."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	tellen.stagger_combats = 1
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"])
	assert_true(CombatContext.participant(battle, tellen, tellen.cell, tellen.equipped_weapon()).staggered)
	assert_eq(CombatForecast.build(battle, tellen, foe, tellen.cell).attacker.follow_up_percent, 0)


func test_kill_gives_exp_drops_and_removes_unit() -> void:
	var battle: BattleState = BattleFixtures.state(["...."])
	battle.rng = ScriptedRng.new([0, 99])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	var drops: Array[ItemData] = [_item("items/elixir")]
	var foe: UnitState = UnitState.generic(&"foe", load(DATA + "classes/brigand.tres") as ClassData, 2, battle.ruleset, &"enemy",
		Vector2i(1, 0), [_item("weapons/iron_axe")], &"normal", drops)
	battle.add_unit(foe)
	foe.current_hp = 1
	var attack := AttackCommand.new(&"tellen", &"foe", 0)
	attack.execute(battle)
	assert_false(foe.is_alive())
	assert_null(battle.unit_at(Vector2i(1, 0)), "removed from the map")
	assert_false(foe.retreated, "enemies are defeated, not retreated")
	assert_eq(attack.defeats.size(), 1)
	assert_eq(attack.defeats[0].items_given, [_item("items/elixir")] as Array[ItemData])
	assert_eq(tellen.inventory.back().item.id, &"elixir")
	assert_false(tellen.inventory.back().drops)
	# Lv1 vs Lv2 kill: combat 10 + 1 = 11, kill bonus 20 + 3 = 23
	assert_eq(attack.reports[&"tellen"].exp_gained, 34)
	assert_eq(tellen.experience, 34)
	assert_false(attack.reports.has(&"foe"), "enemies do not gain EXP")


func test_drop_lost_when_inventory_full() -> void:
	var battle: BattleState = BattleFixtures.state(["...."])
	battle.rng = ScriptedRng.new([0, 99])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	while tellen.has_inventory_space(battle.ruleset):
		tellen.inventory.append(InventorySlot.of(_item("items/vulnerary")))
	var drops: Array[ItemData] = [_item("items/elixir")]
	var foe: UnitState = UnitState.generic(&"foe", load(DATA + "classes/brigand.tres") as ClassData, 1, battle.ruleset, &"enemy",
		Vector2i(1, 0), [_item("weapons/iron_axe")], &"normal", drops)
	battle.add_unit(foe)
	foe.current_hp = 1
	var attack := AttackCommand.new(&"tellen", &"foe", 0)
	attack.execute(battle)
	assert_eq(attack.defeats[0].items_lost.size(), 1)


func test_player_unit_retreats() -> void:
	var battle: BattleState = BattleFixtures.state(["...."])
	battle.phase_index = 1
	battle.rng = ScriptedRng.new([0, 99])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	tellen.current_hp = 1
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"])
	var attack := AttackCommand.new(&"foe", &"tellen", 0)
	attack.execute(battle)
	assert_true(tellen.retreated)
	assert_null(battle.unit_at(Vector2i(0, 0)))


func test_defender_gains_exp_and_proficiency() -> void:
	var battle: BattleState = BattleFixtures.state(["...."])
	battle.phase_index = 1
	battle.rng = ScriptedRng.new([99, 0, 99])  # enemy misses, Tellen's counter hits
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"])
	var points_before: int = tellen.proficiency_points.get(&"sword", 0)
	var attack := AttackCommand.new(&"foe", &"tellen", 0)
	attack.execute(battle)
	assert_gt(attack.reports[&"tellen"].exp_gained, 1)
	assert_eq(tellen.proficiency_points[&"sword"], points_before + 1, "Beginner primary +1")


# Progression -----------------------------------------------------------------------

func test_level_up_at_100_exp_and_multiple_levels() -> void:
	var battle: BattleState = BattleFixtures.state(["."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	tellen.experience = 90
	var report := ProgressionService.Report.new()
	ProgressionService.award_exp(battle, tellen, 230, report)
	assert_eq(tellen.level, 4, "90 + 230 = 320 → +3 levels")
	assert_eq(tellen.experience, 20)
	assert_eq(report.level_gains.size(), 3)
	assert_true(report.leveled_up())


func test_level_up_respects_caps_and_raises_current_hp() -> void:
	var battle: BattleState = BattleFixtures.state(["."])
	var ruleset: Ruleset = battle.ruleset.duplicate() as Ruleset
	var growth := CrossroadsGrowthRules.new()
	growth.growth_mode = CrossroadsGrowthRules.GrowthMode.FIXED
	ruleset.growth_rules = growth
	battle.ruleset = ruleset
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	tellen.current_hp = 5
	tellen.stats.set_value(&"str", tellen.class_data.caps.get_value(&"str"))
	tellen.growth_counters = {&"hp": 50, &"str": 90}
	var gains: StatBlock = ProgressionService.level_up(battle, tellen)
	assert_eq(gains.get_value(&"hp"), 1, "50 + 65 → +1")
	assert_eq(gains.get_value(&"str"), 0, "capped")
	assert_eq(tellen.current_hp, 6, "current HP rises with max HP")


func test_level_cap_stops_exp() -> void:
	var battle: BattleState = BattleFixtures.state(["."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	tellen.level = battle.ruleset.level_cap
	var report := ProgressionService.Report.new()
	ProgressionService.award_exp(battle, tellen, 50, report)
	assert_eq(tellen.experience, 0)
	assert_eq(report.exp_gained, 0)


func test_proficiency_level_up() -> void:
	var battle: BattleState = BattleFixtures.state(["."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	assert_eq(tellen.proficiencies[&"sword"], 1)
	assert_eq(tellen.proficiency_points[&"sword"], 10, "starts at the level-1 threshold")
	var report := ProgressionService.Report.new()
	for i: int in 15:
		ProgressionService.train_proficiency(battle, tellen, &"sword", report)
	assert_eq(tellen.proficiencies[&"sword"], 2, "25 points")
	assert_eq(report.proficiency_ups[&"sword"], 2)
	ProgressionService.train_proficiency(battle, tellen, &"axe", report)
	assert_false(tellen.proficiency_points.has(&"axe"), "Sellswords do not train axes")


# Healing and items -------------------------------------------------------------------

func test_heal_command() -> void:
	var battle: BattleState = BattleFixtures.state(["..."])
	var acolyte: UnitState = _named(battle, "recruit_acolyte", &"player", Vector2i(0, 0))
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(1, 0))
	assert_false(HealCommand.new(&"recruit_acolyte", &"tellen", 0).can_execute(battle), "Tellen is at full HP")
	tellen.current_hp = 3
	var heal := HealCommand.new(&"recruit_acolyte", &"tellen", 0)
	assert_true(heal.can_execute(battle))
	heal.execute(battle)
	var expected: int = mini(tellen.max_hp(battle.ruleset), 3 + acolyte.stats.get_value(&"mag") + 10)
	assert_eq(tellen.current_hp, expected)
	assert_eq(heal.amount, expected - 3)
	assert_eq(heal.report.exp_gained, 12)
	assert_true(acolyte.has_acted)


func test_vulnerary_heals_and_uses_up() -> void:
	var battle: BattleState = BattleFixtures.state(["."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	tellen.inventory[1].uses = 1
	assert_false(InventoryCommands.Use.new(&"tellen", 1).can_execute(battle), "full HP: no point")
	tellen.current_hp = 4
	var use := InventoryCommands.Use.new(&"tellen", 1)
	assert_true(use.can_execute(battle))
	use.execute(battle)
	assert_eq(tellen.current_hp, 14)
	assert_eq(use.healed, 10)
	assert_eq(tellen.inventory.size(), 1, "last use removes the item")
	assert_true(tellen.has_acted)


func test_booster_raises_stat_within_cap() -> void:
	var battle: BattleState = BattleFixtures.state(["."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	tellen.inventory.append(InventorySlot.of(_item("items/might_tonic")))
	tellen.inventory.append(InventorySlot.of(_item("items/vital_charm")))
	var str_before: int = tellen.stats.get_value(&"str")
	InventoryCommands.Use.new(&"tellen", 2).execute(battle)
	assert_eq(tellen.stats.get_value(&"str"), str_before + 2)
	tellen.has_acted = false
	var hp_before: int = tellen.current_hp
	InventoryCommands.Use.new(&"tellen", 2).execute(battle)
	assert_eq(tellen.max_hp(battle.ruleset), hp_before + 7)
	assert_eq(tellen.current_hp, hp_before + 7, "HP booster raises current HP too")


func test_equip_and_discard_are_free_actions() -> void:
	var battle: BattleState = BattleFixtures.state(["."])
	var gid: UnitState = _named(battle, "gid", &"player", Vector2i(0, 0))
	var equip := InventoryCommands.Equip.new(&"gid", 1)
	assert_true(equip.can_execute(battle))
	equip.execute(battle)
	assert_eq(gid.equipped_weapon().id, &"hand_axe")
	assert_false(gid.has_acted)
	InventoryCommands.Discard.new(&"gid", 1).execute(battle)
	assert_eq(gid.inventory.size(), 1)
	assert_false(InventoryCommands.Equip.new(&"gid", 5).can_execute(battle))


func test_trade_swap_and_give() -> void:
	var battle: BattleState = BattleFixtures.state(["...."])
	var tellen: UnitState = _named(battle, "tellen", &"player", Vector2i(0, 0))
	var gid: UnitState = _named(battle, "gid", &"player", Vector2i(1, 0))
	var far: UnitState = _named(battle, "sable", &"player", Vector2i(3, 0))
	assert_false(InventoryCommands.Trade.new(&"tellen", 0, &"sable", 0).can_execute(battle), "not adjacent")
	var swap := InventoryCommands.Trade.new(&"tellen", 1, &"gid", 0)
	assert_true(swap.can_execute(battle))
	swap.execute(battle)
	assert_eq(tellen.inventory[1].item.id, &"iron_axe")
	assert_eq(gid.inventory[0].item.id, &"vulnerary")
	var give := InventoryCommands.Trade.new(&"tellen", 0, &"gid", gid.inventory.size())
	assert_true(give.can_execute(battle))
	give.execute(battle)
	assert_eq(tellen.inventory.size(), 1)
	assert_eq(gid.inventory.back().item.id, &"iron_sword")
	assert_false(tellen.has_acted, "trading is free")
	assert_eq(far.inventory.size(), 2)
