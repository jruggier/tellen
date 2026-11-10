extends GutTest
## TurnManager: phase order, per-phase cleanup, healing, skipping empty factions.


func _battle() -> BattleState:
	var battle: BattleState = BattleFixtures.state([".T..", "...."])
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 0), ["iron_sword"])
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(3, 1), ["iron_axe"])
	return battle


func test_phase_order_and_turns() -> void:
	var battle: BattleState = _battle()
	var report: TurnManager.PhaseReport = TurnManager.start_battle(battle)
	assert_eq([battle.turn, report.faction_id], [1, &"player"])
	report = TurnManager.end_phase(battle)
	assert_eq([battle.turn, report.faction_id], [1, &"enemy"])
	report = TurnManager.end_phase(battle)
	assert_eq([battle.turn, report.faction_id], [2, &"player"], "ally faction has no units: skipped")


func test_units_refresh_when_their_phase_ends() -> void:
	var battle: BattleState = _battle()
	TurnManager.start_battle(battle)
	var me: UnitState = battle.get_unit(&"me")
	var foe: UnitState = battle.get_unit(&"foe")
	me.has_acted = true
	TurnManager.end_phase(battle)
	assert_false(me.has_acted, "player units look fresh during the enemy phase")
	foe.has_acted = true
	me.has_acted = true
	TurnManager.end_phase(battle)
	assert_false(foe.has_acted, "enemies refreshed when their phase ends")
	assert_false(me.has_acted, "and the player's phase readies its units")


func test_stagger_clears_at_phase_end() -> void:
	var battle: BattleState = _battle()
	TurnManager.start_battle(battle)
	battle.get_unit(&"foe").stagger_combats = 1
	TurnManager.end_phase(battle)
	assert_false(battle.get_unit(&"foe").is_staggered())


func test_fort_heals_at_own_phase_start() -> void:
	var battle: BattleState = _battle()
	TurnManager.start_battle(battle)
	var me: UnitState = battle.get_unit(&"me")
	battle.move_unit(&"me", Vector2i(1, 0))
	me.current_hp = 5
	var report: TurnManager.PhaseReport = TurnManager.end_phase(battle)
	assert_eq(me.current_hp, 5, "no healing on the enemy's phase start")
	report = TurnManager.end_phase(battle)
	var expected: int = maxi(1, floori(me.max_hp(battle.ruleset) * 0.2))
	assert_eq(me.current_hp, 5 + expected)
	assert_eq(report.healed[&"me"], expected)


func test_all_acted() -> void:
	var battle: BattleState = _battle()
	assert_false(TurnManager.all_acted(battle, &"player"))
	battle.get_unit(&"me").has_acted = true
	assert_true(TurnManager.all_acted(battle, &"player"))


func test_end_phase_command_events() -> void:
	var battle: BattleState = _battle()
	TurnManager.start_battle(battle)
	var command := EndPhaseCommand.new(&"player")
	assert_false(EndPhaseCommand.new(&"enemy").can_execute(battle), "only the current faction can end its phase")
	assert_true(command.can_execute(battle))
	watch_signals(TacticsEvents)
	command.execute(battle)
	command.emit_events(TacticsEvents)
	assert_signal_emitted_with_parameters(TacticsEvents, "phase_ended", [&"player", 1])
	assert_signal_emitted_with_parameters(TacticsEvents, "phase_started", [&"enemy", 1])
