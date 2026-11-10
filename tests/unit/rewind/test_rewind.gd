extends GutTest
## RewindService (§9.6): snapshots at player-action boundaries, exact restore.

const DATA: String = "res://game/data/"


func _controller() -> BattleController:
	var map := BattleMap.new()
	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = load("res://game/tilesets/prototype_terrain.tres") as TileSet
	for y: int in 5:
		for x: int in 8:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	map.add_child(layer)
	var factions: Array[FactionData] = [load(DATA + "factions/player.tres"), load(DATA + "factions/enemy.tres")]
	map.factions = factions
	var placements: Array[UnitPlacement] = []
	for entry: Array in [["tellen", Vector2i(1, 2)], ["sable", Vector2i(1, 3)]]:
		var p := UnitPlacement.new()
		p.unit_data = load(DATA + "units/%s.tres" % entry[0]) as UnitData
		p.faction_id = &"player"
		p.cell = entry[1]
		placements.append(p)
	var foe := UnitPlacement.new()
	foe.class_data = load(DATA + "classes/brigand.tres") as ClassData
	foe.cell = Vector2i(4, 2)
	foe.items = [load(DATA + "weapons/iron_axe.tres")]
	placements.append(foe)
	map.placements = placements
	add_child_autofree(map)
	var controller := BattleController.new()
	add_child_autofree(controller)
	controller.setup(map, BattleFixtures.ruleset(), 99)
	controller.start()
	return controller


func test_one_snapshot_per_player_action() -> void:
	var controller: BattleController = _controller()
	var rewind := RewindService.new(controller, 3)
	controller.execute(MoveCommand.new(&"tellen", Vector2i(3, 2)))
	controller.execute(AttackCommand.new(&"tellen", &"brigand_1", 0))
	assert_eq(rewind.points.size(), 1, "move + attack = one action")
	controller.execute(InventoryCommands.Equip.new(&"sable", 0))
	controller.execute(WaitCommand.new(&"sable"))
	assert_eq(rewind.points.size(), 2, "equip then wait = one action")
	assert_eq(rewind.points[1].actor_id, &"sable")
	controller.execute(EndPhaseCommand.new(&"player"))
	assert_eq(rewind.points.size(), 3, "ending the turn is a rewind point")
	controller.execute(MoveCommand.new(&"brigand_1", Vector2i(4, 1)))
	assert_eq(rewind.points.size(), 3, "no snapshots during the enemy phase")


func test_rewind_restores_exact_state_and_rng() -> void:
	var controller: BattleController = _controller()
	var rewind := RewindService.new(controller, 3)
	var before_hp: int = controller.state.get_unit(&"brigand_1").current_hp
	controller.execute(MoveCommand.new(&"tellen", Vector2i(3, 2)))
	var attack := AttackCommand.new(&"tellen", &"brigand_1", 0)
	controller.execute(attack)
	var first_result: Dictionary = attack.result.to_dict()
	assert_eq(controller.action_log.size(), 2)
	rewind.rewind_to(0)
	var state: BattleState = controller.state
	assert_eq(state.get_unit(&"tellen").cell, Vector2i(1, 2))
	assert_false(state.get_unit(&"tellen").has_acted)
	assert_eq(state.get_unit(&"brigand_1").current_hp, before_hp)
	assert_eq(controller.action_log.size(), 0, "log truncated")
	assert_eq(rewind.charges_left, 2)
	assert_eq(rewind.points.size(), 0, "later points dropped")
	controller.execute(MoveCommand.new(&"tellen", Vector2i(3, 2)))
	var again := AttackCommand.new(&"tellen", &"brigand_1", 0)
	controller.execute(again)
	assert_eq(again.result.to_dict(), first_result, "same RNG state, same combat")
	assert_same(TacticsRng.get_rng(), controller.state.rng)


func test_rewind_undoes_enemy_phase() -> void:
	var controller: BattleController = _controller()
	var rewind := RewindService.new(controller, 3)
	controller.execute(EndPhaseCommand.new(&"player"))
	controller.execute(MoveCommand.new(&"brigand_1", Vector2i(2, 2)))
	controller.execute(WaitCommand.new(&"brigand_1"))
	controller.execute(EndPhaseCommand.new(&"enemy"))
	assert_eq(controller.state.turn, 2)
	rewind.rewind_to(0)
	assert_eq(controller.state.turn, 1)
	assert_eq(controller.state.current_faction().id, &"player")
	assert_eq(controller.state.get_unit(&"brigand_1").cell, Vector2i(4, 2))


func test_campaign_flags_restored() -> void:
	var controller: BattleController = _controller()
	var rewind := RewindService.new(controller, 3)
	controller.execute(MoveCommand.new(&"tellen", Vector2i(2, 2)))
	controller.state.campaign.flags["chose_badly"] = true
	controller.execute(WaitCommand.new(&"tellen"))
	rewind.rewind_to(0)
	assert_false(controller.state.campaign.flags.has("chose_badly"))


func test_charges_run_out() -> void:
	var controller: BattleController = _controller()
	var rewind := RewindService.new(controller, 1)
	controller.execute(WaitCommand.new(&"tellen"))
	assert_true(rewind.can_rewind())
	rewind.rewind_to(0)
	controller.execute(WaitCommand.new(&"tellen"))
	assert_false(rewind.can_rewind(), "no charges left")
	assert_null(rewind.rewind_to(0))


func test_cancelled_move_drops_its_snapshot() -> void:
	var controller: BattleController = _controller()
	var rewind := RewindService.new(controller, 3)
	controller.execute(MoveCommand.new(&"tellen", Vector2i(2, 2)))
	assert_eq(rewind.points.size(), 1)
	controller.undo_last()
	assert_eq(rewind.points.size(), 0)
	controller.execute(MoveCommand.new(&"tellen", Vector2i(2, 1)))
	assert_eq(rewind.points.size(), 1, "the re-done move captures again")
