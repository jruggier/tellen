extends GutTest
## Chain attacks (§9.4).


func _battle(ruleset: Ruleset = null) -> BattleState:
	var battle: BattleState = BattleFixtures.state([".....", ".....", "....."], ruleset)
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(1, 1), ["iron_sword"])
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(2, 1), ["iron_axe"])
	foe.stats.set_value(&"hp", 40)
	foe.current_hp = 40
	return battle


func test_contributors_need_reach_and_no_stagger() -> void:
	var battle: BattleState = _battle()
	var me: UnitState = battle.get_unit(&"me")
	var foe: UnitState = battle.get_unit(&"foe")
	BattleFixtures.add(battle, &"adjacent", "sellsword", &"player", Vector2i(2, 0), ["iron_sword"])
	BattleFixtures.add(battle, &"archer", "hunter", &"player", Vector2i(4, 1), ["iron_bow"])
	BattleFixtures.add(battle, &"far", "sellsword", &"player", Vector2i(4, 2), ["iron_sword"])
	var dazed: UnitState = BattleFixtures.add(battle, &"dazed", "sellsword", &"player", Vector2i(2, 2), ["iron_sword"])
	dazed.stagger_combats = 1
	var ids: Array[StringName] = []
	for ally: UnitState in ChainAttacks.contributors(battle, me, foe):
		ids.append(ally.id)
	assert_eq(ids, [&"adjacent", &"archer"] as Array[StringName], "bow at 2 counts; out of reach and Staggered don't")


func test_chain_damage_and_strikes() -> void:
	var battle: BattleState = _battle()
	battle.rng = ScriptedRng.new([99, 99, 99, 99])
	BattleFixtures.add(battle, &"ally", "sellsword", &"player", Vector2i(2, 0), ["iron_sword"])
	var attack := AttackCommand.new(&"me", &"foe", 0)
	attack.execute(battle)
	var chain: Array[Strike] = []
	for strike: Strike in attack.result.strikes:
		if strike.kind == Strike.Kind.CHAIN:
			chain.append(strike)
	assert_eq(chain.size(), 1)
	assert_eq(chain[0].damage, 4, "10% of 40")
	assert_eq(chain[0].chain_unit_id, &"ally")
	assert_false(chain[0].crit)
	assert_eq(battle.get_unit(&"foe").current_hp, 36, "main combat all missed; chain landed")
	assert_eq(attack.chain_units, [&"ally"] as Array[StringName])


func test_minimum_one_damage() -> void:
	var battle: BattleState = _battle()
	var foe: UnitState = battle.get_unit(&"foe")
	foe.stats.set_value(&"hp", 5)
	assert_eq(ChainAttacks.strike_damage(battle, foe), 1)


func test_chain_can_kill_flag() -> void:
	var ruleset: Ruleset = BattleFixtures.ruleset().duplicate() as Ruleset
	ruleset.chain_can_kill = false
	var battle: BattleState = _battle(ruleset)
	battle.rng = ScriptedRng.new([99, 99, 99, 99])
	BattleFixtures.add(battle, &"ally", "sellsword", &"player", Vector2i(2, 0), ["iron_sword"])
	battle.get_unit(&"foe").current_hp = 2
	AttackCommand.new(&"me", &"foe", 0).execute(battle)
	assert_eq(battle.get_unit(&"foe").current_hp, 1, "stops at 1 HP")
	ruleset.chain_can_kill = true
	var battle2: BattleState = _battle(ruleset)
	battle2.rng = ScriptedRng.new([99, 99, 99, 99])
	BattleFixtures.add(battle2, &"ally", "sellsword", &"player", Vector2i(2, 0), ["iron_sword"])
	battle2.get_unit(&"foe").current_hp = 2
	var attack := AttackCommand.new(&"me", &"foe", 0)
	attack.execute(battle2)
	assert_false(battle2.get_unit(&"foe").is_alive(), "chain finishes it")
	assert_eq(attack.defeats.size(), 1)


func test_disabled() -> void:
	var ruleset: Ruleset = BattleFixtures.ruleset().duplicate() as Ruleset
	ruleset.chain_attacks_enabled = false
	var battle: BattleState = _battle(ruleset)
	BattleFixtures.add(battle, &"ally", "sellsword", &"player", Vector2i(2, 0), ["iron_sword"])
	assert_eq(ChainAttacks.preview(battle, battle.get_unit(&"me"), battle.get_unit(&"foe")), Vector2i.ZERO)


func test_preview_and_awakening_charge() -> void:
	var ruleset: Ruleset = BattleFixtures.ruleset().duplicate() as Ruleset
	var rule := ActionChargeAwakeningRule.new()
	ruleset.awakening_rule = rule
	var battle: BattleState = _battle(ruleset)
	var sable: UnitState = UnitState.from_unit_data(&"sable", load("res://game/data/units/sable.tres") as UnitData, ruleset, &"player", Vector2i(2, 2))
	battle.add_unit(sable)
	rule.on_unit_added(battle, sable)
	assert_eq(ChainAttacks.preview(battle, battle.get_unit(&"me"), battle.get_unit(&"foe")), Vector2i(4, 1))
	battle.rng = ScriptedRng.new([99, 99, 99, 99])
	AttackCommand.new(&"me", &"foe", 0).execute(battle)
	assert_eq(sable.awaken_charge, 4, "+1 for joining a chain")


func test_enemies_chain_too() -> void:
	var battle: BattleState = _battle()
	battle.phase_index = 1
	battle.rng = ScriptedRng.new([99, 99, 99, 99])
	BattleFixtures.add(battle, &"foe2", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"])
	var attack := AttackCommand.new(&"foe", &"me", 0)
	attack.execute(battle)
	assert_eq(attack.chain_units, [&"foe2"] as Array[StringName])
