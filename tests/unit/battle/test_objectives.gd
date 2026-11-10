extends GutTest
## Objectives, defeat conditions, reinforcements, trigger regions, difficulty.

const DATA: String = "res://game/data/"


func _battle() -> BattleState:
	var battle: BattleState = BattleFixtures.state(["......", "......", "......"])
	BattleFixtures.add(battle, &"me", "sellsword", &"player", Vector2i(0, 0), ["iron_sword"])
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(5, 2), ["iron_axe"])
	return battle


func _defeat(battle: BattleState, unit_id: StringName) -> void:
	DefeatRules.apply(battle, battle.get_unit(unit_id), null)


func _outcome(battle: BattleState, objectives: Array[Objective] = [], conditions: Array[DefeatCondition] = []) -> ObjectiveRules.Outcome:
	return ObjectiveRules.evaluate(battle, objectives, conditions)


func test_default_rout_and_defeat() -> void:
	var battle: BattleState = _battle()
	assert_eq(_outcome(battle), ObjectiveRules.Outcome.ONGOING)
	_defeat(battle, &"foe")
	assert_eq(_outcome(battle), ObjectiveRules.Outcome.VICTORY)
	var lost: BattleState = _battle()
	_defeat(lost, &"me")
	assert_eq(_outcome(lost), ObjectiveRules.Outcome.DEFEAT, "all player units gone")


func test_rout_waits_for_pending_reinforcements() -> void:
	var battle: BattleState = _battle()
	var reinforcement := Reinforcement.new()
	var placement := UnitPlacement.new()
	placement.class_data = load(DATA + "classes/brigand.tres") as ClassData
	placement.cell = Vector2i(5, 0)
	reinforcement.placements = [placement]
	ReinforcementRules.queue(battle, [reinforcement])
	_defeat(battle, &"foe")
	assert_eq(_outcome(battle), ObjectiveRules.Outcome.ONGOING)


func test_lord_defeat_is_game_over() -> void:
	var battle: BattleState = _battle()
	var tellen: UnitState = UnitState.from_unit_data(&"tellen", load(DATA + "units/tellen.tres") as UnitData, battle.ruleset, &"player", Vector2i(1, 1))
	battle.add_unit(tellen)
	_defeat(battle, &"tellen")
	assert_eq(_outcome(battle), ObjectiveRules.Outcome.DEFEAT)


func test_seize() -> void:
	var battle: BattleState = _battle()
	var tellen: UnitState = UnitState.from_unit_data(&"tellen", load(DATA + "units/tellen.tres") as UnitData, battle.ruleset, &"player", Vector2i(3, 1))
	battle.add_unit(tellen)
	var seize := SeizeObjective.new()
	seize.cell = Vector2i(3, 1)
	var objectives: Array[Objective] = [seize]
	assert_false(SeizeCommand.new(&"me", objectives).can_execute(battle), "only the protagonist seizes")
	var command := SeizeCommand.new(&"tellen", objectives)
	assert_true(command.can_execute(battle))
	assert_eq(_outcome(battle, objectives), ObjectiveRules.Outcome.ONGOING)
	command.execute(battle)
	assert_eq(_outcome(battle, objectives), ObjectiveRules.Outcome.VICTORY, "enemies remain, but seizing wins")


func test_defeat_boss() -> void:
	var battle: BattleState = _battle()
	battle.get_unit(&"foe").is_boss = true
	BattleFixtures.add(battle, &"minion", "brigand", &"enemy", Vector2i(5, 0), ["iron_axe"])
	var objectives: Array[Objective] = [DefeatBossObjective.new()]
	_defeat(battle, &"foe")
	assert_eq(_outcome(battle, objectives), ObjectiveRules.Outcome.VICTORY)


func test_survive_and_turn_limit() -> void:
	var battle: BattleState = _battle()
	var survive := SurviveObjective.new()
	survive.turns = 3
	var objectives: Array[Objective] = [survive]
	battle.turn = 3
	assert_eq(_outcome(battle, objectives), ObjectiveRules.Outcome.ONGOING)
	battle.turn = 4
	assert_eq(_outcome(battle, objectives), ObjectiveRules.Outcome.VICTORY)
	var limit := DefeatCondition.make(DefeatCondition.Kind.TURN_LIMIT)
	limit.turn_limit = 3
	var conditions: Array[DefeatCondition] = [limit]
	assert_eq(_outcome(battle, [], conditions), ObjectiveRules.Outcome.DEFEAT)


func test_defend_tile() -> void:
	var battle: BattleState = _battle()
	var defend := DefendTileObjective.new()
	defend.cell = Vector2i(2, 1)
	defend.turns = 2
	var objectives: Array[Objective] = [defend]
	battle.move_unit(&"foe", Vector2i(2, 1))
	assert_eq(_outcome(battle, objectives), ObjectiveRules.Outcome.DEFEAT, "enemy on the tile")
	battle.move_unit(&"foe", Vector2i(5, 2))
	battle.turn = 3
	assert_eq(_outcome(battle, objectives), ObjectiveRules.Outcome.VICTORY)


func test_escape() -> void:
	var battle: BattleState = _battle()
	var escape := EscapeObjective.new()
	escape.cells = [Vector2i(0, 0)]
	escape.count = 1
	var objectives: Array[Objective] = [escape]
	var command := EscapeCommand.new(&"me", objectives)
	assert_true(command.can_execute(battle))
	command.execute(battle)
	assert_null(battle.unit_at(Vector2i(0, 0)))
	assert_eq(_outcome(battle, objectives), ObjectiveRules.Outcome.VICTORY, "escaped units don't count as defeated")


func test_protected_unit() -> void:
	var battle: BattleState = _battle()
	var guard := DefeatCondition.make(DefeatCondition.Kind.UNIT_DEFEATED)
	guard.unit_id = &"me"
	var conditions: Array[DefeatCondition] = [guard]
	_defeat(battle, &"me")
	assert_eq(_outcome(battle, [], conditions), ObjectiveRules.Outcome.DEFEAT)


# Reinforcements -------------------------------------------------------------------------

func _reinforcement(turn: int, cell: Vector2i, telegraph: bool = true) -> Reinforcement:
	var reinforcement := Reinforcement.new()
	reinforcement.turn = turn
	reinforcement.telegraph = telegraph
	var placement := UnitPlacement.new()
	placement.class_data = load(DATA + "classes/brigand.tres") as ClassData
	placement.cell = cell
	var axe: Array[ItemData] = [load(DATA + "weapons/iron_axe.tres")]
	placement.items = axe
	reinforcement.placements = [placement]
	return reinforcement


func test_reinforcements_arrive_on_time_and_cannot_act() -> void:
	var battle: BattleState = _battle()
	ReinforcementRules.queue(battle, [_reinforcement(2, Vector2i(5, 0))])
	TurnManager.start_battle(battle)
	assert_null(battle.unit_at(Vector2i(5, 0)))
	TurnManager.end_phase(battle)  # enemy turn 1
	assert_null(battle.unit_at(Vector2i(5, 0)), "not yet: turn 1")
	TurnManager.end_phase(battle)  # player turn 2
	assert_null(battle.unit_at(Vector2i(5, 0)), "arrives on the enemy's phase")
	var report: TurnManager.PhaseReport = TurnManager.end_phase(battle)  # enemy turn 2
	var arrival: UnitState = battle.unit_at(Vector2i(5, 0))
	assert_not_null(arrival)
	assert_eq(report.spawned, [arrival.id] as Array[StringName])
	assert_false(arrival.is_ready(), "never acts on the phase it appears")
	assert_eq(AIPlanner.turn_order(battle, &"enemy").has(arrival), false)


func test_telegraph_shown_during_preceding_player_phase_only() -> void:
	var battle: BattleState = _battle()
	ReinforcementRules.queue(battle, [_reinforcement(2, Vector2i(5, 0)), _reinforcement(2, Vector2i(4, 0), false)])
	TurnManager.start_battle(battle)
	assert_eq(ReinforcementRules.telegraphed_cells(battle).size(), 0, "turn 1 player phase: arrival is more than a round away")
	TurnManager.end_phase(battle)
	assert_eq(ReinforcementRules.telegraphed_cells(battle).size(), 0, "never during enemy phases")
	TurnManager.end_phase(battle)
	assert_eq(ReinforcementRules.telegraphed_cells(battle), [Vector2i(5, 0)] as Array[Vector2i], "turn 2 player phase: warned (untelegraphed one hidden)")


func test_blocked_arrival_waits() -> void:
	var battle: BattleState = _battle()
	ReinforcementRules.queue(battle, [_reinforcement(1, Vector2i(0, 0))])
	TurnManager.start_battle(battle)
	TurnManager.end_phase(battle)
	assert_eq(battle.unit_at(Vector2i(0, 0)).id, &"me", "tile occupied: delayed")
	assert_eq(battle.pending_arrivals.size(), 1)
	battle.move_unit(&"me", Vector2i(1, 0))
	TurnManager.end_phase(battle)
	TurnManager.end_phase(battle)
	assert_ne(battle.unit_at(Vector2i(0, 0)).id, &"me", "arrives once the tile is free")


func test_trigger_region_fires_once_and_undo_restores() -> void:
	var battle: BattleState = _battle()
	var sleeper: UnitState = battle.get_unit(&"foe")
	var profile := AIProfile.new()
	profile.behavior = AIProfile.Behavior.AGGRO_REGION
	sleeper.ai_profile = profile
	sleeper.ai_group = &"camp"
	var region := TriggerRegion.new()
	region.rect = Rect2i(2, 0, 2, 3)
	region.wake_groups = [&"camp"]
	region.set_flags = ["bridge_reached"]
	battle.trigger_regions = [region]
	var move := MoveCommand.new(&"me", Vector2i(2, 0))
	move.execute(battle)
	assert_eq(move.fired_regions.size(), 1)
	assert_true(sleeper.ai_awake)
	assert_true(battle.flags.get("bridge_reached", false))
	move.undo(battle)
	assert_false(sleeper.ai_awake, "undoing the move undoes the trigger")
	assert_false(battle.flags.has("bridge_reached"))


# Difficulty -------------------------------------------------------------------------------

func test_difficulty_raises_generic_stats() -> void:
	var map: BattleMap = (load("res://game/maps/test_arena.tscn") as PackedScene).instantiate() as BattleMap
	add_child_autofree(map)
	var normal := BattleController.new()
	var hard := BattleController.new()
	add_child_autofree(normal)
	add_child_autofree(hard)
	normal.setup(map, BattleFixtures.ruleset(), 1, &"normal")
	hard.setup(map, BattleFixtures.ruleset(), 1, &"hard")
	var total_normal: int = 0
	var total_hard: int = 0
	for unit: UnitState in normal.state.units_of(&"enemy"):
		total_normal += unit.stats.get_value(&"hp") + unit.stats.get_value(&"str")
	for unit: UnitState in hard.state.units_of(&"enemy"):
		total_hard += unit.stats.get_value(&"hp") + unit.stats.get_value(&"str")
	assert_gt(total_hard, total_normal)
	var tellen_normal: UnitState = normal.state.get_unit(&"tellen")
	var tellen_hard: UnitState = hard.state.get_unit(&"tellen")
	assert_true(tellen_normal.stats.equals(tellen_hard.stats), "named player units are unaffected")
