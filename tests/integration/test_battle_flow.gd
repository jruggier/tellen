extends GutTest
## Commands, battle setup from a BattleMap, and the select/move/cancel/wait
## flow through the real battle scene (driven headlessly).

const DATA: String = "res://game/data/"


## A 8x5 plains map with forest at (3,0) and water at (5,2).
## Player: Tellen (1,2), recruit spearhand (2,2). Enemy: brigand (6,2).
func _make_map() -> BattleMap:
	var map := BattleMap.new()
	map.map_id = &"test_flow"
	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = load("res://game/tilesets/prototype_terrain.tres") as TileSet
	for y: int in 5:
		for x: int in 8:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(3, 0), 0, Vector2i(2, 0))
	layer.set_cell(Vector2i(5, 2), 0, Vector2i(6, 0))
	map.add_child(layer)
	var factions: Array[FactionData] = [load(DATA + "factions/player.tres"), load(DATA + "factions/enemy.tres")]
	map.factions = factions
	var tellen := UnitPlacement.new()
	tellen.unit_data = load(DATA + "units/tellen.tres") as UnitData
	tellen.faction_id = &"player"
	tellen.cell = Vector2i(1, 2)
	var spear := UnitPlacement.new()
	spear.unit_data = load(DATA + "units/recruit_spearhand.tres") as UnitData
	spear.faction_id = &"player"
	spear.cell = Vector2i(2, 2)
	var brigand := UnitPlacement.new()
	brigand.class_data = load(DATA + "classes/brigand.tres") as ClassData
	brigand.level = 2
	brigand.faction_id = &"enemy"
	brigand.cell = Vector2i(6, 2)
	var axe: Array[ItemData] = [load(DATA + "weapons/iron_axe.tres")]
	brigand.items = axe
	var placements: Array[UnitPlacement] = [tellen, spear, brigand]
	map.placements = placements
	return map


func _make_scene() -> BattleScene:
	var scene: BattleScene = (load("res://game/scenes/battle_scene.tscn") as PackedScene).instantiate() as BattleScene
	scene.map_instance = _make_map()
	scene.battle_seed = 7
	scene.move_seconds_per_cell = 0.0
	add_child_autofree(scene)
	return scene


# Setup ------------------------------------------------------------------------------

func test_setup_builds_state_from_map() -> void:
	var map: BattleMap = _make_map()
	add_child_autofree(map)
	var controller := BattleController.new()
	add_child_autofree(controller)
	controller.setup(map, BattleFixtures.ruleset(), 1)
	var state: BattleState = controller.state
	assert_eq(state.grid.get_rect(), Rect2i(0, 0, 8, 5))
	assert_eq(state.all_units().size(), 3)
	assert_not_null(state.get_unit(&"tellen"))
	assert_not_null(state.get_unit(&"brigand_1"), "generic ids are class id + counter")
	assert_eq(state.unit_at(Vector2i(6, 2)).id, &"brigand_1")
	assert_eq(state.get_unit(&"brigand_1").equipped_weapon().id, &"iron_axe")
	assert_eq(state.get_unit(&"tellen").current_hp, state.get_unit(&"tellen").max_hp(state.ruleset))
	assert_same(TacticsRng.get_rng(), state.rng, "battle RNG is the active RNG")


func test_bad_placements_are_skipped_with_warnings() -> void:
	var map: BattleMap = _make_map()
	var orphan := UnitPlacement.new()
	orphan.cell = Vector2i(0, 0)
	var stranger := UnitPlacement.new()
	stranger.class_data = load(DATA + "classes/brigand.tres") as ClassData
	stranger.faction_id = &"pirates"
	map.placements.append(orphan)
	map.placements.append(stranger)
	add_child_autofree(map)
	var controller := BattleController.new()
	add_child_autofree(controller)
	controller.setup(map, BattleFixtures.ruleset(), 1)
	assert_eq(controller.state.all_units().size(), 3)
	assert_push_warning_count(2)


# Commands ---------------------------------------------------------------------------

func test_move_command_validates_executes_and_undoes() -> void:
	var battle: BattleState = BattleFixtures.state([".....", "....."])
	battle.phase_index = 0
	var unit: UnitState = BattleFixtures.add(battle, &"a", "sellsword", &"player", Vector2i(0, 0))
	assert_false(MoveCommand.new(&"a", Vector2i(4, 1)).can_execute(battle), "distance 5 > mov 4")
	assert_false(MoveCommand.new(&"nobody", Vector2i(1, 0)).can_execute(battle))
	var move := MoveCommand.new(&"a", Vector2i(2, 1))
	assert_true(move.can_execute(battle))
	var version: int = battle.version
	move.execute(battle)
	assert_eq(unit.cell, Vector2i(2, 1))
	assert_true(unit.has_moved)
	assert_eq(battle.unit_at(Vector2i(2, 1)), unit)
	assert_null(battle.unit_at(Vector2i(0, 0)))
	assert_gt(battle.version, version)
	assert_eq(move.path.front(), Vector2i(0, 0))
	assert_eq(move.path.back(), Vector2i(2, 1))
	assert_false(MoveCommand.new(&"a", Vector2i(3, 1)).can_execute(battle), "already moved")
	move.undo(battle)
	assert_eq(unit.cell, Vector2i(0, 0))
	assert_false(unit.has_moved)
	assert_eq(move.to_dict()["type"], "move")


func test_commands_respect_current_phase() -> void:
	var battle: BattleState = BattleFixtures.state(["...."])
	BattleFixtures.add(battle, &"foe", "brigand", &"enemy", Vector2i(0, 0))
	assert_false(MoveCommand.new(&"foe", Vector2i(1, 0)).can_execute(battle), "player phase")
	assert_false(WaitCommand.new(&"foe").can_execute(battle))
	battle.phase_index = 1
	assert_true(MoveCommand.new(&"foe", Vector2i(1, 0)).can_execute(battle))


func test_wait_command() -> void:
	var battle: BattleState = BattleFixtures.state(["..."])
	var unit: UnitState = BattleFixtures.add(battle, &"a", "sellsword", &"player", Vector2i(0, 0))
	var wait := WaitCommand.new(&"a")
	assert_true(wait.can_execute(battle))
	wait.execute(battle)
	assert_true(unit.has_acted)
	assert_false(unit.is_ready())
	assert_false(WaitCommand.new(&"a").can_execute(battle))


func test_controller_logs_emits_and_undoes() -> void:
	var map: BattleMap = _make_map()
	add_child_autofree(map)
	var controller := BattleController.new()
	add_child_autofree(controller)
	controller.setup(map, BattleFixtures.ruleset(), 1)
	watch_signals(TacticsEvents)
	watch_signals(controller)
	assert_false(controller.execute(MoveCommand.new(&"tellen", Vector2i(7, 4))), "illegal move rejected")
	assert_push_warning_count(1)
	assert_true(controller.execute(MoveCommand.new(&"tellen", Vector2i(1, 0))))
	assert_signal_emitted(TacticsEvents, "unit_moved")
	assert_signal_emitted(controller, "command_executed")
	assert_eq(controller.action_log.size(), 1)
	assert_true(controller.can_undo())
	assert_true(controller.undo_last())
	assert_eq(controller.state.get_unit(&"tellen").cell, Vector2i(1, 2))
	assert_eq(controller.action_log.size(), 0)
	assert_false(controller.undo_last())


# Scene flow -------------------------------------------------------------------------

func test_scene_builds_and_starts_on_first_player_unit() -> void:
	var scene: BattleScene = _make_scene()
	await wait_process_frames(1)
	assert_eq(scene.cursor.cell, Vector2i(1, 2))
	assert_eq(scene.unit_views.size(), 3)
	assert_eq(scene.input.state, PlayerInputController.State.IDLE)
	assert_eq(scene.camera.zoom, Vector2(4, 4))
	assert_true(scene.terrain_panel.visible)


func test_select_move_wait() -> void:
	var scene: BattleScene = _make_scene()
	var input: PlayerInputController = scene.input
	input.confirm()
	assert_eq(input.state, PlayerInputController.State.SELECTED)
	assert_eq(input.get_selected().id, &"tellen")
	scene.cursor.set_cell(Vector2i(3, 2))
	input.confirm()
	await wait_process_frames(2)
	assert_eq(input.state, PlayerInputController.State.MOVED)
	var tellen: UnitState = scene.controller.state.get_unit(&"tellen")
	assert_eq(tellen.cell, Vector2i(3, 2))
	assert_eq(scene.unit_views[&"tellen"].position, Vector2(3, 2) * 16)
	input.confirm()
	assert_eq(input.state, PlayerInputController.State.IDLE)
	assert_true(tellen.has_acted)
	scene.cursor.set_cell(Vector2i(3, 2))
	input.confirm()
	assert_eq(input.state, PlayerInputController.State.INSPECT, "acted units can only be inspected")


func test_cancel_after_move_undoes_it() -> void:
	var scene: BattleScene = _make_scene()
	var input: PlayerInputController = scene.input
	input.confirm()
	scene.cursor.set_cell(Vector2i(1, 4))
	input.confirm()
	await wait_process_frames(2)
	input.cancel()
	var tellen: UnitState = scene.controller.state.get_unit(&"tellen")
	assert_eq(tellen.cell, Vector2i(1, 2))
	assert_false(tellen.has_moved)
	assert_eq(input.state, PlayerInputController.State.SELECTED, "back to choosing a destination")
	assert_eq(scene.unit_views[&"tellen"].position, Vector2(1, 2) * 16)
	input.cancel()
	assert_eq(input.state, PlayerInputController.State.IDLE)


func test_cannot_stop_on_ally_or_out_of_range() -> void:
	var scene: BattleScene = _make_scene()
	var input: PlayerInputController = scene.input
	input.confirm()
	scene.cursor.set_cell(Vector2i(7, 0))
	input.confirm()
	assert_eq(input.state, PlayerInputController.State.SELECTED, "out of range: nothing happens")
	scene.cursor.set_cell(Vector2i(2, 2))
	input.confirm()
	assert_eq(input.get_selected().id, &"recruit_spearhand", "confirming on another ready ally switches selection")


func test_inspect_enemy_and_threat_toggle() -> void:
	var scene: BattleScene = _make_scene()
	var input: PlayerInputController = scene.input
	scene.cursor.set_cell(Vector2i(6, 2))
	input.confirm()
	assert_eq(input.state, PlayerInputController.State.INSPECT)
	input.cancel()
	assert_eq(input.state, PlayerInputController.State.IDLE)
	input.toggle_threat()
	assert_true(scene.overlay.is_threat_visible())
	input.toggle_threat()
	assert_false(scene.overlay.is_threat_visible())


func test_cycle_units() -> void:
	var scene: BattleScene = _make_scene()
	scene.input.cycle_unit(1)
	assert_eq(scene.cursor.cell, Vector2i(2, 2))
	scene.input.cycle_unit(1)
	assert_eq(scene.cursor.cell, Vector2i(1, 2))
	scene.input.cycle_unit(-1)
	assert_eq(scene.cursor.cell, Vector2i(2, 2))


func test_path_preview_follows_cursor() -> void:
	var scene: BattleScene = _make_scene()
	scene.input.confirm()
	scene.cursor.set_cell(Vector2i(4, 2))
	assert_eq(scene.path_arrow._path.back(), Vector2i(4, 2))
	scene.cursor.set_cell(Vector2i(7, 4))
	assert_eq(scene.path_arrow._path.size(), 0, "no arrow to unreachable cells")


func test_debug_overlay_toggles_and_tracks_movement_type() -> void:
	var scene: BattleScene = _make_scene()
	await wait_process_frames(1)
	var debug: DebugOverlay = scene.debug_overlay
	assert_not_null(debug, "present in debug builds")
	assert_false(debug.visible)
	debug.toggle()
	assert_true(debug.visible)
	assert_eq(debug.get_movement_type_id(), &"foot", "cursor starts on Tellen (foot)")
	scene.cursor.set_cell(Vector2i(0, 0))
	assert_eq(debug.get_movement_type_id(), &"foot", "empty cell: first movement type")
	debug.toggle()
	assert_false(debug.visible)
