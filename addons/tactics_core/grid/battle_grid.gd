class_name BattleGrid
extends RefCounted
## The battle map as data: which [TerrainData] is on each cell.
##
## Pure data (no Nodes) so battles can run headless for tests, AI and
## replays. Build one from a [TileMapLayer] whose TileSet has a custom data
## layer (named by [member Ruleset.terrain_id_layer]) holding each tile's
## terrain id, or from text rows in tests.
##
## Cells use the TileMapLayer's coordinates. Cells inside the map rectangle
## with no tile, or with an unknown terrain id, are impassable for everyone
## (unknown ids are logged as content errors).

## Neighbor order is fixed (up, right, down, left) so pathfinding ties
## always break the same way.
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var _rect: Rect2i = Rect2i()
var _terrain: Dictionary[Vector2i, TerrainData] = {}


## Builds a grid from [param layer], resolving terrain ids through [param ruleset].
static func from_tile_map_layer(layer: TileMapLayer, ruleset: Ruleset) -> BattleGrid:
	var grid := BattleGrid.new()
	grid._rect = layer.get_used_rect()
	var layer_name: String = ruleset.terrain_id_layer
	if layer.tile_set == null or not layer.tile_set.has_custom_data_layer_by_name(layer_name):
		TacticsLog.warn("BattleGrid", "%s: TileSet has no '%s' custom data layer; every cell is impassable" % [layer.get_path(), layer_name])
		return grid
	var unknown: Dictionary[String, int] = {}
	for cell: Vector2i in layer.get_used_cells():
		var tile: TileData = layer.get_cell_tile_data(cell)
		var terrain_id: String = str(tile.get_custom_data(layer_name)) if tile != null else ""
		var terrain: TerrainData = ruleset.get_terrain(StringName(terrain_id)) if not terrain_id.is_empty() else null
		if terrain == null:
			unknown[terrain_id] = unknown.get(terrain_id, 0) + 1
			continue
		grid._terrain[cell] = terrain
	for terrain_id: String in unknown:
		TacticsLog.warn("BattleGrid", "%s: %d cell(s) with unknown terrain id '%s' are impassable" % [layer.get_path(), unknown[terrain_id], terrain_id])
	return grid


## Builds a grid from text rows (one character per cell, top-left = 0,0)
## using [param legend] (character → terrain). Unknown characters are void.
static func from_rows(rows: PackedStringArray, legend: Dictionary) -> BattleGrid:
	var grid := BattleGrid.new()
	var width: int = 0
	for y: int in rows.size():
		width = maxi(width, rows[y].length())
		for x: int in rows[y].length():
			var key: String = rows[y][x]
			if legend.has(key):
				grid._terrain[Vector2i(x, y)] = legend[key]
	grid._rect = Rect2i(0, 0, width, rows.size())
	return grid


## The map rectangle in cell coordinates.
func get_rect() -> Rect2i:
	return _rect


## True if [param cell] lies inside the map rectangle.
func in_bounds(cell: Vector2i) -> bool:
	return _rect.has_point(cell)


## Terrain on [param cell], or null for void/unknown cells.
func terrain_at(cell: Vector2i) -> TerrainData:
	return _terrain.get(cell, null)


## Movement cost of [param cell] for [param movement_type_id], or -1 if impassable.
func move_cost(cell: Vector2i, movement_type_id: StringName) -> int:
	var terrain: TerrainData = terrain_at(cell)
	return terrain.get_move_cost(movement_type_id) if terrain != null else -1


## In-bounds orthogonal neighbors in fixed order.
func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		var next: Vector2i = cell + direction
		if in_bounds(next):
			result.append(next)
	return result


## Every cell that has terrain, in row-major order.
func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in range(_rect.position.y, _rect.end.y):
		for x: int in range(_rect.position.x, _rect.end.x):
			var cell := Vector2i(x, y)
			if _terrain.has(cell):
				result.append(cell)
	return result


## Manhattan distance between two cells.
static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
