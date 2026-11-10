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
	scene.seconds_per_strike = 0.0
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


func _choose(scene: BattleScene, option_id: StringName) -> void:
	var menu_list: MenuList = scene.sub_menu if scene.input.state == PlayerInputController.State.ITEM_ACTIONS else scene.menu
	var index: int = menu_list.option_ids().find(option_id)
	assert_gt(index, -1, "menu offers %s (has %s)" % [option_id, menu_list.option_ids()])
	menu_list.selected = index
	scene.input.confirm()


func test_select_move_wait() -> void:
	var scene: BattleScene = _make_scene()
	var input: PlayerInputController = scene.input
	input.confirm()
	assert_eq(input.state, PlayerInputController.State.SELECTED)
	assert_eq(input.get_selected().id, &"tellen")
	scene.cursor.set_cell(Vector2i(3, 2))
	input.confirm()
	await wait_process_frames(2)
	assert_eq(input.state, PlayerInputController.State.ACTION_MENU)
	assert_true(scene.menu.visible)
	var tellen: UnitState = scene.controller.state.get_unit(&"tellen")
	assert_eq(tellen.cell, Vector2i(3, 2))
	assert_eq(scene.unit_views[&"tellen"].position, Vector2(3, 2) * 16)
	_choose(scene, &"wait")
	assert_eq(input.state, PlayerInputController.State.IDLE)
	assert_true(tellen.has_acted)
	assert_false(scene.menu.visible)
	scene.cursor.set_cell(Vector2i(3, 2))
	input.confirm()
	assert_eq(input.state, PlayerInputController.State.INSPECT, "acted units can only be inspected")


func test_cancel_action_menu_undoes_move() -> void:
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


func test_staying_in_place_opens_menu_without_move() -> void:
	var scene: BattleScene = _make_scene()
	scene.input.confirm()
	scene.input.confirm()
	assert_eq(scene.input.state, PlayerInputController.State.ACTION_MENU)
	assert_true(scene.menu.option_ids().has(&"trade"), "spearhand is adjacent")
	assert_false(scene.menu.option_ids().has(&"attack"), "nobody in range")
	scene.input.cancel()
	assert_eq(scene.input.state, PlayerInputController.State.SELECTED)


func _scene_with_adjacent_brigand() -> BattleScene:
	var scene: BattleScene = (load("res://game/scenes/battle_scene.tscn") as PackedScene).instantiate() as BattleScene
	var map: BattleMap = _make_map()
	map.placements[2].cell = Vector2i(3, 2)
	scene.map_instance = map
	scene.battle_seed = 7
	scene.move_seconds_per_cell = 0.0
	scene.seconds_per_strike = 0.0
	add_child_autofree(scene)
	return scene


func test_attack_flow_with_forecast() -> void:
	var scene: BattleScene = _scene_with_adjacent_brigand()
	var input: PlayerInputController = scene.input
	var state: BattleState = scene.controller.state
	input.confirm()
	scene.cursor.set_cell(Vector2i(3, 1))
	input.confirm()
	await wait_process_frames(2)
	_choose(scene, &"attack")
	assert_eq(input.state, PlayerInputController.State.TARGETING, "one weapon: straight to targeting")
	assert_eq(input.get_target().id, &"brigand_1")
	assert_true(scene.forecast_panel.visible)
	input.toggle_info()
	input.cancel()
	assert_eq(input.state, PlayerInputController.State.ACTION_MENU)
	_choose(scene, &"attack")
	var brigand: UnitState = state.get_unit(&"brigand_1")
	var hp_before: int = brigand.current_hp
	watch_signals(input)
	input.confirm()
	await wait_process_frames(2)
	assert_signal_emitted(input, "action_finished")
	assert_eq(input.state, PlayerInputController.State.IDLE)
	assert_true(state.get_unit(&"tellen").has_acted)
	assert_eq(scene.controller.action_log.entries().back()["type"], "attack")
	assert_true(brigand.current_hp < hp_before or state.get_unit(&"tellen").experience == 1, "hit, or missed for 1 EXP")


func test_defeat_drop_and_level_up_flow() -> void:
	var scene: BattleScene = _scene_with_adjacent_brigand()
	var input: PlayerInputController = scene.input
	var state: BattleState = scene.controller.state
	var brigand: UnitState = state.get_unit(&"brigand_1")
	brigand.current_hp = 1
	brigand.inventory.append(InventorySlot.of(load(DATA + "items/elixir.tres") as ItemData, true))
	var tellen: UnitState = state.get_unit(&"tellen")
	tellen.experience = 90
	state.rng = ScriptedRng.new([0, 99])
	input.confirm()
	scene.cursor.set_cell(Vector2i(3, 1))
	input.confirm()
	await wait_process_frames(2)
	_choose(scene, &"attack")
	input.confirm()
	await wait_process_frames(2)
	assert_eq(input.state, PlayerInputController.State.LEVEL_UP, "kill EXP pushes past 100")
	assert_true(scene.level_panel.visible)
	assert_eq(tellen.level, 2)
	input.confirm()
	await wait_process_frames(2)
	assert_eq(input.state, PlayerInputController.State.IDLE)
	assert_false(scene.level_panel.visible)
	assert_false(brigand.is_alive())
	assert_false(scene.unit_views[&"brigand_1"].visible)
	assert_eq(tellen.inventory.back().item.id, &"elixir", "drop received")


func test_heal_flow() -> void:
	var scene: BattleScene = (load("res://game/scenes/battle_scene.tscn") as PackedScene).instantiate() as BattleScene
	var map: BattleMap = _make_map()
	map.placements[1].unit_data = load(DATA + "units/recruit_acolyte.tres") as UnitData
	scene.map_instance = map
	scene.move_seconds_per_cell = 0.0
	scene.seconds_per_strike = 0.0
	add_child_autofree(scene)
	var state: BattleState = scene.controller.state
	var tellen: UnitState = state.get_unit(&"tellen")
	tellen.current_hp = 4
	scene.cursor.set_cell(Vector2i(2, 2))
	scene.input.confirm()
	scene.input.confirm()
	_choose(scene, &"heal")
	assert_eq(scene.input.state, PlayerInputController.State.TARGETING)
	assert_true(scene.forecast_panel.visible, "heal preview")
	scene.input.confirm()
	await wait_process_frames(2)
	assert_gt(tellen.current_hp, 4)
	assert_eq(scene.input.state, PlayerInputController.State.IDLE)


func test_use_item_flow() -> void:
	var scene: BattleScene = _make_scene()
	var tellen: UnitState = scene.controller.state.get_unit(&"tellen")
	tellen.current_hp = 5
	scene.input.confirm()
	scene.input.confirm()
	_choose(scene, &"items")
	assert_eq(scene.input.state, PlayerInputController.State.ITEM_MENU)
	_choose(scene, &"1")
	assert_eq(scene.input.state, PlayerInputController.State.ITEM_ACTIONS)
	_choose(scene, &"use")
	await wait_process_frames(2)
	assert_eq(tellen.current_hp, 15)
	assert_true(tellen.has_acted)
	assert_eq(scene.input.state, PlayerInputController.State.IDLE)


func test_equip_locks_in_move_and_returns_to_items() -> void:
	var scene: BattleScene = _make_scene()
	var tellen: UnitState = scene.controller.state.get_unit(&"tellen")
	tellen.inventory.append(InventorySlot.of(load(DATA + "weapons/steel_sword.tres") as ItemData))
	scene.input.confirm()
	scene.cursor.set_cell(Vector2i(1, 3))
	scene.input.confirm()
	await wait_process_frames(2)
	_choose(scene, &"items")
	_choose(scene, &"2")
	_choose(scene, &"equip")
	assert_eq(scene.input.state, PlayerInputController.State.ITEM_MENU, "back to the item list")
	assert_eq(tellen.equipped_weapon().id, &"steel_sword")
	scene.input.cancel()
	assert_eq(scene.input.state, PlayerInputController.State.ACTION_MENU)
	scene.input.cancel()
	assert_eq(scene.input.state, PlayerInputController.State.ACTION_MENU, "equipping locked in the move")
	assert_eq(tellen.cell, Vector2i(1, 3))


func test_trade_flow() -> void:
	var scene: BattleScene = _make_scene()
	var state: BattleState = scene.controller.state
	var tellen: UnitState = state.get_unit(&"tellen")
	var spear: UnitState = state.get_unit(&"recruit_spearhand")
	scene.input.confirm()
	scene.input.confirm()
	_choose(scene, &"trade")
	assert_eq(scene.input.state, PlayerInputController.State.TRADING, "single partner: straight to the trade screen")
	scene.input.move_selection(Vector2i.DOWN)
	scene.input.confirm()
	scene.input.confirm()
	assert_eq(tellen.inventory[1].item.id, &"javelin", "vulnerary swapped with the javelin in the same row")
	assert_eq(spear.inventory[1].item.id, &"vulnerary")
	scene.input.cancel()
	assert_eq(scene.input.state, PlayerInputController.State.ACTION_MENU)
	scene.input.cancel()
	assert_eq(scene.input.state, PlayerInputController.State.ACTION_MENU, "trading locked in the turn: cannot undo")
	_choose(scene, &"wait")
	assert_true(tellen.has_acted)


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
