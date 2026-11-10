extends GutTest
## BattleGrid built from a TileMapLayer and from text rows.

var ruleset: Ruleset


func before_all() -> void:
	ruleset = load("res://game/rules/crossroads_ruleset.tres") as Ruleset


func _layer() -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = load("res://game/tilesets/prototype_terrain.tres") as TileSet
	add_child_autofree(layer)
	return layer


func test_reads_terrain_ids_from_tileset() -> void:
	var layer: TileMapLayer = _layer()
	# atlas x: 0 plains, 2 forest, 6 water
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(1, 0), 0, Vector2i(2, 0))
	layer.set_cell(Vector2i(2, 1), 0, Vector2i(6, 0))
	var grid: BattleGrid = BattleGrid.from_tile_map_layer(layer, ruleset)
	assert_eq(grid.get_rect(), Rect2i(0, 0, 3, 2))
	assert_eq(grid.terrain_at(Vector2i(0, 0)).id, &"plains")
	assert_eq(grid.terrain_at(Vector2i(1, 0)).id, &"forest")
	assert_eq(grid.move_cost(Vector2i(1, 0), &"foot"), 2)
	assert_eq(grid.move_cost(Vector2i(1, 0), &"ground"), 3)
	assert_eq(grid.move_cost(Vector2i(2, 1), &"foot"), -1, "water")
	assert_eq(grid.move_cost(Vector2i(2, 1), &"sky"), 1)
	assert_null(grid.terrain_at(Vector2i(0, 1)), "unpainted cell inside rect is void")
	assert_eq(grid.move_cost(Vector2i(0, 1), &"sky"), -1)
	assert_eq(grid.cells(), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 1)] as Array[Vector2i])


func test_every_tile_maps_to_ruleset_terrain() -> void:
	var tileset: TileSet = load("res://game/tilesets/prototype_terrain.tres") as TileSet
	var source: TileSetAtlasSource = tileset.get_source(0) as TileSetAtlasSource
	for i: int in source.get_tiles_count():
		var coords: Vector2i = source.get_tile_id(i)
		var terrain_id: String = source.get_tile_data(coords, 0).get_custom_data("terrain_id")
		assert_not_null(ruleset.get_terrain(StringName(terrain_id)), "tile %s → '%s'" % [coords, terrain_id])
	assert_eq(source.get_tiles_count(), ruleset.terrains.size(), "one tile per terrain")


func test_missing_custom_data_layer_warns() -> void:
	var layer := TileMapLayer.new()
	var tileset := TileSet.new()
	var source := TileSetAtlasSource.new()
	source.texture = load("res://game/tilesets/prototype_terrain.png") as Texture2D
	source.texture_region_size = Vector2i(16, 16)
	source.create_tile(Vector2i(0, 0))
	tileset.add_source(source, 0)
	layer.tile_set = tileset
	add_child_autofree(layer)
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	var grid: BattleGrid = BattleGrid.from_tile_map_layer(layer, ruleset)
	assert_null(grid.terrain_at(Vector2i(0, 0)))
	assert_push_warning_count(1)


func test_from_rows_and_neighbors() -> void:
	var plains: TerrainData = ruleset.get_terrain(&"plains")
	var grid: BattleGrid = BattleGrid.from_rows(["...", ". ."], {".": plains})
	assert_eq(grid.get_rect(), Rect2i(0, 0, 3, 2))
	assert_null(grid.terrain_at(Vector2i(1, 1)))
	assert_eq(grid.neighbors(Vector2i(0, 0)), [Vector2i(1, 0), Vector2i(0, 1)] as Array[Vector2i])
	assert_eq(grid.neighbors(Vector2i(1, 0)), [Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 0)] as Array[Vector2i])
	assert_eq(BattleGrid.distance(Vector2i(0, 0), Vector2i(2, -3)), 5)


func test_ruleset_terrain_catalog() -> void:
	assert_eq(ruleset.terrains.size(), 9)
	assert_eq(ruleset.get_terrain(&"fort").heal_percent, 20)
	assert_null(ruleset.get_terrain(&"lava"))
	assert_eq(ruleset.cell_size(), 64)
