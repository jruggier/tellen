extends GutTest
## game/maps/test_arena.tscn: every terrain type, legal placements, playable.


func _arena_state() -> BattleState:
	var map: BattleMap = (load("res://game/maps/test_arena.tscn") as PackedScene).instantiate() as BattleMap
	add_child_autofree(map)
	var controller := BattleController.new()
	add_child_autofree(controller)
	controller.setup(map, BattleFixtures.ruleset(), 1)
	return controller.state


func test_arena_has_every_terrain_type() -> void:
	var state: BattleState = _arena_state()
	var seen: Dictionary[StringName, bool] = {}
	for cell: Vector2i in state.grid.cells():
		seen[state.grid.terrain_at(cell).id] = true
	for terrain: TerrainData in state.ruleset.terrains:
		assert_true(seen.has(terrain.id), "arena uses %s" % terrain.id)


func test_arena_is_larger_than_the_screen() -> void:
	var state: BattleState = _arena_state()
	var cells_on_screen := Vector2(1920, 1080) / float(state.ruleset.cell_size())
	assert_gt(state.grid.get_rect().size.x, cells_on_screen.x, "camera must scroll horizontally")
	assert_gt(state.grid.get_rect().size.y, cells_on_screen.y, "camera must scroll vertically")


func test_arena_units_are_placed_legally() -> void:
	var state: BattleState = _arena_state()
	assert_eq(state.units_of(&"player").size(), 6)
	assert_eq(state.units_of(&"enemy").size(), 9)
	var movement_types: Dictionary[StringName, bool] = {}
	for unit: UnitState in state.all_units():
		assert_gt(state.grid.move_cost(unit.cell, unit.movement_type_id()), 0, "%s stands on passable terrain" % unit.id)
		movement_types[unit.movement_type_id()] = true
		if unit.faction_id == &"enemy":
			assert_not_null(unit.equipped_weapon(), "%s is armed" % unit.id)
	assert_eq(movement_types.size(), 4, "foot, ground, sky and heavy all present")


func test_arena_loads_without_warnings() -> void:
	_arena_state()
	assert_push_warning_count(0)
	assert_push_error_count(0)
