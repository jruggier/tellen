extends GutTest
## Map markers and MapDefinition feeding the battle (§12).

const DATA: String = "res://game/data/"


func _unit(unit_id: String) -> UnitData:
	return load(DATA + "units/%s.tres" % unit_id) as UnitData


func _map() -> BattleMap:
	var map := BattleMap.new()
	map.name = "TestMap"
	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = load("res://game/tilesets/prototype_terrain.tres") as TileSet
	for y: int in 8:
		for x: int in 10:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	map.add_child(layer)
	var definition := MapDefinition.new()
	definition.map_id = &"marker_test"
	var factions: Array[FactionData] = [load(DATA + "factions/player.tres"), load(DATA + "factions/enemy.tres")]
	definition.factions = factions
	definition.pre_battle_dialogue = &"arena_intro"
	definition.turn_limit = 9
	map.definition = definition
	var markers := Node2D.new()
	markers.name = "Markers"
	map.add_child(markers)
	return map


func _add(map: BattleMap, marker: MapMarker, cell: Vector2i, parent: Node = null) -> MapMarker:
	(parent if parent != null else map.get_node("Markers")).add_child(marker)
	marker.set_cell(cell)
	return marker


func _spawn(map: BattleMap, slot: int, cell: Vector2i, forced: UnitData = null) -> PlayerSpawn:
	var spawn := PlayerSpawn.new()
	spawn.slot = slot
	spawn.forced_unit = forced
	_add(map, spawn, cell)
	return spawn


func test_cells_and_snapping() -> void:
	var map: BattleMap = _map()
	add_child_autofree(map)
	var spawn := PlayerSpawn.new()
	map.get_node("Markers").add_child(spawn)
	spawn.position = Vector2(37, 21)
	assert_false(spawn.is_on_grid())
	spawn.snap_to_grid()
	assert_eq(spawn.position, Vector2(32, 16))
	assert_eq(spawn.get_cell(), Vector2i(2, 1))
	assert_eq(spawn.cell_size(), 16, "read from the terrain tileset")


func test_markers_hidden_in_game() -> void:
	var map: BattleMap = _map()
	var spawn: PlayerSpawn = _spawn(map, 0, Vector2i(1, 1))
	add_child_autofree(map)
	assert_false(spawn.visible)


func test_deployment_forced_units_and_limit() -> void:
	var map: BattleMap = _map()
	_spawn(map, 0, Vector2i(0, 0))
	_spawn(map, 1, Vector2i(1, 0), _unit("gid"))
	_spawn(map, 2, Vector2i(2, 0))
	_spawn(map, 3, Vector2i(3, 0))
	map.definition.forced_units = [_unit("tellen")]
	map.definition.deploy_count = 3
	add_child_autofree(map)
	var roster: Array[UnitData] = [_unit("sable"), _unit("tellen"), _unit("recruit_hunter"), _unit("recruit_acolyte")]
	var deployed: Array[UnitPlacement] = map.deploy(roster)
	var by_cell: Dictionary = {}
	for placement: UnitPlacement in deployed:
		by_cell[placement.cell] = placement.unit_data.id
	assert_eq(deployed.size(), 3, "deploy count 3")
	assert_eq(by_cell[Vector2i(1, 0)], &"gid", "forced on its own slot")
	assert_eq(by_cell[Vector2i(0, 0)], &"tellen", "definition's forced unit first")
	assert_eq(by_cell[Vector2i(2, 0)], &"sable", "then the roster, in order")
	assert_false(by_cell.has(Vector2i(3, 0)))


func test_accessors_merge_definition_and_markers() -> void:
	var map: BattleMap = _map()
	var foe := EnemyUnit.new()
	foe.class_data = load(DATA + "classes/brigand.tres") as ClassData
	foe.level = 3
	foe.is_boss = true
	foe.stat_overrides = StatBlock.from_values({"skl": 1})
	_add(map, foe, Vector2i(8, 4))
	var ally := AllyUnit.new()
	ally.class_data = load(DATA + "classes/sellsword.tres") as ClassData
	_add(map, ally, Vector2i(5, 5))
	var group := ReinforcementGroup.new()
	group.turn = 3
	_add(map, group, Vector2i(9, 0))
	var arrival := EnemyUnit.new()
	arrival.class_data = load(DATA + "classes/brigand.tres") as ClassData
	_add(map, arrival, Vector2i(9, 1), group)
	var seize := SeizeTile.new()
	_add(map, seize, Vector2i(9, 7))
	for cell: Vector2i in [Vector2i(0, 7), Vector2i(1, 7)]:
		var escape := EscapeTile.new()
		escape.count = 2
		_add(map, escape, cell)
	var region := RegionMarker.new()
	region.size_cells = Vector2i(2, 2)
	region.event = MapEvent.new()
	region.event.wake_groups = [&"camp"]
	_add(map, region, Vector2i(4, 2))
	var chest := ChestMarker.new()
	chest.give_items = [load(DATA + "items/elixir.tres")]
	_add(map, chest, Vector2i(7, 7))
	add_child_autofree(map)

	assert_eq(map.get_map_id(), &"marker_test")
	assert_eq(map.get_factions().size(), 2)
	var placements: Array[UnitPlacement] = map.get_placements([])
	assert_eq(placements.size(), 2, "the reinforcement isn't placed at start")
	assert_eq(placements[0].faction_id, &"enemy")
	assert_eq(placements[1].faction_id, &"ally")
	var reinforcements: Array[Reinforcement] = map.get_reinforcements()
	assert_eq(reinforcements.size(), 1)
	assert_eq(reinforcements[0].placements[0].cell, Vector2i(9, 1), "child markers keep map cells")
	var objectives: Array[Objective] = map.get_objectives()
	assert_eq(objectives.size(), 2, "seize + one combined escape")
	assert_eq((objectives[0] as SeizeObjective).cell, Vector2i(9, 7))
	assert_eq((objectives[1] as EscapeObjective).cells.size(), 2)
	assert_eq((objectives[1] as EscapeObjective).count, 2)
	var defeat: Array[DefeatCondition] = map.get_defeat_conditions()
	assert_eq(defeat.back().kind, DefeatCondition.Kind.TURN_LIMIT)
	var events: Array[MapEvent] = map.get_events()
	var triggers: Array[int] = []
	for event: MapEvent in events:
		triggers.append(event.trigger)
	assert_eq(triggers, [MapEvent.Trigger.MAP_START, MapEvent.Trigger.REGION, MapEvent.Trigger.VISIT] as Array[int])
	assert_eq(events[1].region, Rect2i(4, 2, 2, 2))
	assert_eq(events[2].action_label, "ACTION_OPEN")


func test_battle_built_from_markers() -> void:
	var map: BattleMap = _map()
	_spawn(map, 0, Vector2i(0, 0))
	_spawn(map, 1, Vector2i(1, 0))
	var foe := EnemyUnit.new()
	foe.class_data = load(DATA + "classes/brigand.tres") as ClassData
	foe.items = [load(DATA + "weapons/iron_axe.tres")]
	foe.stat_overrides = StatBlock.from_values({"skl": 1, "hp": 30})
	_add(map, foe, Vector2i(8, 4))
	add_child_autofree(map)
	var controller := BattleController.new()
	add_child_autofree(controller)
	var roster: Array[UnitData] = [_unit("tellen"), _unit("sable"), _unit("gid")]
	controller.setup(map, BattleFixtures.ruleset(), 1, &"normal", roster)
	var state: BattleState = controller.state
	assert_eq(state.map_id, &"marker_test")
	assert_eq(state.units_of(&"player").size(), 2, "two spawn slots")
	assert_eq(state.unit_at(Vector2i(0, 0)).id, &"tellen")
	var brigand: UnitState = state.unit_at(Vector2i(8, 4))
	assert_eq(brigand.stats.get_value(&"skl"), 1, "stat override")
	assert_eq(brigand.current_hp, 30)


func test_marker_validation() -> void:
	var map: BattleMap = _map()
	var empty_unit := EnemyUnit.new()
	_add(map, empty_unit, Vector2i(1, 1))
	var empty_region := RegionMarker.new()
	_add(map, empty_region, Vector2i(2, 2))
	var empty_village := VillageMarker.new()
	_add(map, empty_village, Vector2i(3, 3))
	add_child_autofree(map)
	assert_eq(empty_unit.validate_marker().size(), 1)
	assert_eq(empty_region.validate_marker().size(), 1)
	assert_eq(empty_village.validate_marker().size(), 1)


func test_negated_required_flag() -> void:
	var battle: BattleState = BattleFixtures.state(["..."])
	var event := MapEvent.new()
	event.id = &"ambush"
	event.required_flag = "!paid_toll"
	var events: Array[MapEvent] = [event]
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.MAP_START).size(), 1)
	battle.campaign.flags["paid_toll"] = true
	assert_eq(MapEventRules.matching(battle, events, MapEvent.Trigger.MAP_START).size(), 0)
