extends GutTest
## AI planner: target scoring, every §10 behavior, turn order, determinism
## and the 50 ms per-decision budget.

const DATA: String = "res://game/data/"


func _battle(rows: PackedStringArray = ["..........", "..........", "..........", "..........", ".........."]) -> BattleState:
	var battle: BattleState = BattleFixtures.state(rows)
	battle.phase_index = 1
	return battle


func _profile(behavior: AIProfile.Behavior) -> AIProfile:
	var profile := AIProfile.new()
	profile.behavior = behavior
	return profile


func test_ai_picks_the_obvious_kill() -> void:
	var battle: BattleState = _battle()
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(5, 2), ["iron_axe"], 3)
	var healthy: UnitState = BattleFixtures.add(battle, &"healthy", "sellsword", &"player", Vector2i(3, 2), ["iron_sword"])
	var weak: UnitState = BattleFixtures.add(battle, &"weak", "sellsword", &"player", Vector2i(7, 2), ["iron_sword"])
	weak.current_hp = 3
	var plan: AIPlanner.Plan = AIPlanner.plan(battle, foe)
	assert_eq(plan.action, AIPlanner.Action.ATTACK)
	assert_eq(plan.target_id, &"weak", "the 3 HP unit dies to one hit")
	assert_eq(BattleGrid.distance(plan.destination, weak.cell), 1)
	assert_true(healthy.is_alive())


func test_kill_probability() -> void:
	var rules: CombatRules = BattleFixtures.ruleset().combat_rules
	# Swordsman vs Brigand: 8 + 4 can't kill 24 HP; only an opening crit (24) can: 92% hit × 1% crit
	var forecast: CombatForecast = CombatForecast.calculate(rules, CombatFixtures.swordsman(), CombatFixtures.brigand(), 1)
	assert_almost_eq(AIScorer.kill_probability(forecast, rules), 0.92 * 0.01, 0.0001)
	var weak: CombatParticipant = CombatFixtures.brigand()
	weak.current_hp = 8
	# 8 HP: the opening hit kills (92%); after a miss, only a critical follow-up (12) kills
	assert_almost_eq(AIScorer.kill_probability(CombatForecast.calculate(rules, CombatFixtures.swordsman(), weak, 1), rules), 0.92 + 0.08 * 0.92 * 0.01, 0.0001)


func test_charge_approaches_nearest_target() -> void:
	var battle: BattleState = _battle()
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(9, 2), ["iron_axe"])
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 2), ["iron_sword"])
	var plan: AIPlanner.Plan = AIPlanner.plan(battle, foe)
	assert_eq(plan.action, AIPlanner.Action.WAIT)
	assert_eq(plan.destination, Vector2i(5, 2), "moves its full 4 tiles toward the target")


func test_hold_only_attacks_reachable_targets() -> void:
	var battle: BattleState = _battle()
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(9, 2), ["iron_axe"])
	foe.ai_profile = _profile(AIProfile.Behavior.HOLD)
	var me: UnitState = BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 2), ["iron_sword"])
	assert_eq(AIPlanner.plan(battle, foe).destination, foe.cell, "too far: holds")
	battle.move_unit(&"me", Vector2i(5, 2))
	var plan: AIPlanner.Plan = AIPlanner.plan(battle, foe)
	assert_eq(plan.action, AIPlanner.Action.ATTACK)
	assert_eq(plan.target_id, me.id)


func test_stationary_never_moves() -> void:
	var battle: BattleState = _battle()
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(5, 2), ["iron_axe"])
	foe.ai_profile = _profile(AIProfile.Behavior.STATIONARY)
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(3, 2), ["iron_sword"])
	var plan: AIPlanner.Plan = AIPlanner.plan(battle, foe)
	assert_eq(plan.destination, foe.cell)
	assert_eq(plan.action, AIPlanner.Action.WAIT, "target 2 tiles away, axe reaches 1")
	battle.move_unit(&"me", Vector2i(4, 2))
	assert_eq(AIPlanner.plan(battle, foe).action, AIPlanner.Action.ATTACK)


func test_aggro_region_wakes_and_wakes_group() -> void:
	var battle: BattleState = _battle()
	var profile := _profile(AIProfile.Behavior.AGGRO_REGION)
	profile.trigger_region = Rect2i(4, 0, 6, 5)
	var sleeper: UnitState = BattleFixtures.add(battle, &"sleeper", "brigand", &"enemy", Vector2i(9, 2), ["iron_axe"])
	sleeper.ai_profile = profile
	sleeper.ai_group = &"camp"
	var buddy: UnitState = BattleFixtures.add(battle, &"buddy", "brigand", &"enemy", Vector2i(9, 4), ["iron_axe"])
	buddy.ai_profile = _profile(AIProfile.Behavior.AGGRO_REGION)
	buddy.ai_group = &"camp"
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 2), ["iron_sword"])
	AIRules.wake_by_regions(battle)
	assert_eq(AIPlanner.plan(battle, sleeper).destination, sleeper.cell, "asleep: stays")
	battle.move_unit(&"me", Vector2i(4, 2))
	AIRules.wake_by_regions(battle)
	assert_true(sleeper.ai_awake)
	assert_true(buddy.ai_awake, "group wakes together")
	assert_ne(AIPlanner.plan(battle, buddy).destination, buddy.cell, "awake: charges")


func test_attacked_sleeper_wakes() -> void:
	var battle: BattleState = _battle()
	battle.phase_index = 0
	var sleeper: UnitState = BattleFixtures.add(battle, &"sleeper", "brigand", &"enemy", Vector2i(1, 0), ["iron_axe"])
	sleeper.ai_profile = _profile(AIProfile.Behavior.AGGRO_REGION)
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 0), ["iron_sword"])
	AttackCommand.new(&"me", &"sleeper", 0).execute(battle)
	assert_true(sleeper.ai_awake)


func test_guard_stays_in_radius() -> void:
	var battle: BattleState = _battle()
	var profile := _profile(AIProfile.Behavior.GUARD)
	profile.guard_cell = Vector2i(9, 2)
	profile.guard_radius = 1
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(9, 2), ["iron_axe"])
	foe.ai_profile = profile
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(5, 2), ["iron_sword"])
	var plan: AIPlanner.Plan = AIPlanner.plan(battle, foe)
	assert_lte(BattleGrid.distance(plan.destination, profile.guard_cell), 1)
	assert_eq(plan.action, AIPlanner.Action.WAIT, "target is 4 away; guard won't chase")
	foe.cell = Vector2i(9, 2)
	battle.move_unit(&"me", Vector2i(7, 2))
	assert_eq(AIPlanner.plan(battle, foe).action, AIPlanner.Action.ATTACK, "attacks what comes within reach")


func test_coward_flees_when_hurt() -> void:
	var battle: BattleState = _battle()
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(5, 2), ["iron_axe"])
	foe.ai_profile = _profile(AIProfile.Behavior.COWARD)
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(3, 2), ["iron_sword"])
	assert_eq(AIPlanner.plan(battle, foe).action, AIPlanner.Action.ATTACK, "healthy: fights")
	foe.current_hp = 2
	var plan: AIPlanner.Plan = AIPlanner.plan(battle, foe)
	assert_eq(plan.action, AIPlanner.Action.WAIT)
	assert_gt(BattleGrid.distance(plan.destination, Vector2i(3, 2)), BattleGrid.distance(foe.cell, Vector2i(3, 2)), "runs away")


func test_healer_heals_wounded_ally() -> void:
	var battle: BattleState = _battle()
	var healer: UnitState = BattleFixtures.add(battle, &"healer", "acolyte", &"enemy", Vector2i(8, 2), ["mend"])
	healer.ai_profile = _profile(AIProfile.Behavior.HEALER)
	var friend: UnitState = BattleFixtures.add(battle, &"friend", "brigand", &"enemy", Vector2i(6, 2), ["iron_axe"])
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 0), ["iron_sword"])
	assert_eq(AIPlanner.plan(battle, healer).action, AIPlanner.Action.WAIT, "nobody hurt")
	friend.current_hp = 5
	var plan: AIPlanner.Plan = AIPlanner.plan(battle, healer)
	assert_eq(plan.action, AIPlanner.Action.HEAL)
	assert_eq(plan.target_id, &"friend")
	assert_eq(BattleGrid.distance(plan.destination, friend.cell), 1)


func test_turn_order_attackers_first_then_distance() -> void:
	var battle: BattleState = _battle()
	BattleFixtures.add(battle, &"far", "brigand", &"enemy", Vector2i(9, 4), ["iron_axe"])
	BattleFixtures.add(battle, &"near", "brigand", &"enemy", Vector2i(4, 2), ["iron_axe"])
	BattleFixtures.add(battle, &"mid", "brigand", &"enemy", Vector2i(8, 0), ["iron_axe"])
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 2), ["iron_sword"])
	var ids: Array[StringName] = []
	for unit: UnitState in AIPlanner.turn_order(battle, &"enemy"):
		ids.append(unit.id)
	assert_eq(ids, [&"near", &"mid", &"far"] as Array[StringName])


func test_plans_are_deterministic() -> void:
	var battle: BattleState = _battle()
	var foe: UnitState = BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(5, 2), ["iron_axe", "hand_axe"], 3)
	BattleFixtures.add(battle, &"a", "sellsword", &"player", Vector2i(3, 1), ["iron_sword"])
	BattleFixtures.add(battle, &"b", "hunter", &"player", Vector2i(3, 3), ["iron_bow"])
	var first: AIPlanner.Plan = AIPlanner.plan(battle, foe)
	for i: int in 5:
		var again: AIPlanner.Plan = AIPlanner.plan(battle, foe)
		assert_eq([again.destination, again.target_id, again.slot], [first.destination, first.target_id, first.slot])


func test_decision_time_budget() -> void:
	var rows: PackedStringArray = []
	for y: int in 40:
		rows.append(".F.H.R.U..".repeat(4))
	var battle: BattleState = _battle(rows)
	for i: int in 20:
		BattleFixtures.add(battle, StringName("p%d" % i), "outrider", &"player", Vector2i((i * 3) % 40, 2 + (i % 5)), ["javelin"])
	for i: int in 20:
		BattleFixtures.add(battle, StringName("e%d" % i), "outrider", &"enemy", Vector2i((i * 3 + 1) % 40, 30 + (i % 8)), ["javelin", "iron_sword"])
	var worst: float = 0.0
	for unit: UnitState in battle.units_of(&"enemy"):
		var started: int = Time.get_ticks_usec()
		AIPlanner.plan(battle, unit)
		worst = maxf(worst, (Time.get_ticks_usec() - started) / 1000.0)
	assert_lt(worst, 50.0, "slowest decision %.1f ms" % worst)
