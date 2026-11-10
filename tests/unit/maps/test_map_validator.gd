extends GutTest
## Map validator (§12.4): shipped maps are clean; each check catches its mistake.

const DATA: String = "res://game/data/"

var ruleset: Ruleset
var roster: Array[UnitData] = []


func before_all() -> void:
	ruleset = load("res://game/rules/crossroads_ruleset.tres") as Ruleset
	roster = (load(DATA + "units/test_roster.tres") as UnitRoster).units


func _load_map(path: String) -> BattleMap:
	var map: BattleMap = (load(path) as PackedScene).instantiate() as BattleMap
	add_child_autofree(map)
	return map


func _problems(map: BattleMap) -> PackedStringArray:
	return MapValidator.validate(map, ruleset, roster)


func test_shipped_maps_are_valid() -> void:
	for path: String in ["res://game/maps/_template/map_template.tscn", "res://game/maps/test_arena.tscn",
			"res://game/maps/ch00_ruined_crossroads.tscn", "res://game/maps/ch01_the_bridge_deal.tscn"]:
		var problems: PackedStringArray = _problems(_load_map(path))
		assert_eq(problems.size(), 0, "%s:\n%s" % [path, "\n".join(problems)])


func _template() -> BattleMap:
	return _load_map("res://game/maps/_template/map_template.tscn")


func _has(problems: PackedStringArray, fragment: String) -> bool:
	for problem: String in problems:
		if problem.contains(fragment):
			return true
	return false


func test_catches_unit_on_impassable_and_shared_cells() -> void:
	var map: BattleMap = _template()
	(map.get_node("Terrain") as TileMapLayer).set_cell(Vector2i(24, 8), 0, Vector2i(6, 0))  # water under the brigand
	var twin := EnemyUnit.new()
	twin.class_data = load(DATA + "classes/brigand.tres") as ClassData
	twin.items = [load(DATA + "weapons/iron_axe.tres")]
	map.get_node("Markers/Enemies").add_child(twin)
	twin.set_cell(Vector2i(2, 7))
	var problems: PackedStringArray = _problems(map)
	assert_true(_has(problems, "stands on terrain it cannot occupy"), "\n".join(problems))
	assert_true(_has(problems, "shares its cell"), "\n".join(problems))


func test_catches_unarmed_enemy() -> void:
	var map: BattleMap = _template()
	(map.get_node("Markers/Enemies/Brigand") as EnemyUnit).items = []
	assert_true(_has(_problems(map), "has no weapon"))


func test_catches_off_grid_and_off_map_markers() -> void:
	var map: BattleMap = _template()
	var spawn: PlayerSpawn = map.get_node("Markers/PlayerSlots/Slot1") as PlayerSpawn
	spawn.set_notify_transform(false)
	spawn.position = Vector2(35, 3)
	var far := SeizeTile.new()
	map.get_node("Markers/Objectives").add_child(far)
	far.set_cell(Vector2i(80, 80))
	var problems: PackedStringArray = _problems(map)
	assert_true(_has(problems, "is not on the grid"), "\n".join(problems))
	assert_true(_has(problems, "is outside the map"), "\n".join(problems))


func test_catches_unreachable_objective() -> void:
	var map: BattleMap = _template()
	var terrain: TileMapLayer = map.get_node("Terrain") as TileMapLayer
	for y: int in 17:
		terrain.set_cell(Vector2i(15, y), 0, Vector2i(7, 0))  # a wall across the map
	var seize := SeizeTile.new()
	map.get_node("Markers/Objectives").add_child(seize)
	seize.set_cell(Vector2i(28, 2))
	assert_true(_has(_problems(map), "cannot be reached"))


func test_catches_blocked_reinforcement() -> void:
	var map: BattleMap = _template()
	var group := ReinforcementGroup.new()
	map.get_node("Markers/Reinforcements").add_child(group)
	group.set_cell(Vector2i(24, 8))
	var arrival := EnemyUnit.new()
	arrival.class_data = load(DATA + "classes/brigand.tres") as ClassData
	arrival.items = [load(DATA + "weapons/iron_axe.tres")]
	group.add_child(arrival)
	arrival.set_cell(Vector2i(24, 8))
	assert_true(_has(_problems(map), "is blocked by"))


func test_catches_dialogue_and_event_mistakes() -> void:
	var map: BattleMap = _template()
	map.definition.pre_battle_dialogue = &"no_such_scene"
	var talk := MapEvent.new()
	talk.id = &"talk"
	talk.trigger = MapEvent.Trigger.TALK
	talk.unit_id = &"tellen"
	talk.other_unit_id = &"nobody_7"
	map.definition.events = [talk]
	var bad := DialogueLibrary.new()
	bad.errors.append("ch99.en.dlg: line 3: unknown command @shwo")
	var problems: PackedStringArray = MapValidator.validate(map, ruleset, roster, bad)
	assert_true(_has(problems, "unknown dialogue 'no_such_scene'"), "\n".join(problems))
	assert_true(_has(problems, "refers to unit 'nobody_7'"), "\n".join(problems))
	assert_true(_has(problems, "line 3: unknown command @shwo"), "dialogue parse errors are reported")


func test_catches_boss_objective_without_boss() -> void:
	var map: BattleMap = _template()
	map.definition.objectives = [DefeatBossObjective.new()]
	assert_true(_has(_problems(map), "has no boss"))


func test_catches_unknown_terrain() -> void:
	var map: BattleMap = _template()
	var layer: TileMapLayer = map.get_node("Terrain") as TileMapLayer
	var tileset: TileSet = layer.tile_set.duplicate(true) as TileSet
	var source: TileSetAtlasSource = tileset.get_source(0) as TileSetAtlasSource
	source.get_tile_data(Vector2i(0, 0), 0).set_custom_data("terrain_id", "lava")
	layer.tile_set = tileset
	assert_true(_has(_problems(map), "unknown terrain id 'lava'"))
