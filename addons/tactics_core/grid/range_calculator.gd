class_name RangeCalculator
extends RefCounted
## Movement and attack ranges for units in a [BattleState] (spec §7.3).
##
## Movement: allies can be passed but not stopped on; units of non-allied
## factions block. With the zone-of-control rule on, entering a cell next to
## an enemy that has the ZOC tag ends movement.
## Attack range: every cell within the min–max range of any attack weapon,
## measured from every cell the unit can stop on.


## Movement range of [param unit] from its current cell.
static func movement(state: BattleState, unit: UnitState) -> MoveRange:
	var can_pass: Callable = func(cell: Vector2i) -> bool:
		var occupant: UnitState = state.unit_at(cell)
		return occupant == null or state.are_allied(occupant.faction_id, unit.faction_id)
	var can_stop: Callable = func(cell: Vector2i) -> bool:
		var occupant: UnitState = state.unit_at(cell)
		return occupant == null or occupant == unit
	var must_stop := Callable()
	if state.ruleset != null and state.ruleset.zone_of_control:
		must_stop = func(cell: Vector2i) -> bool: return _in_enemy_zoc(state, unit, cell)
	return Pathfinder.flood(state.grid, unit.cell, unit.mov(state.ruleset), unit.movement_type_id(), can_pass, can_stop, must_stop)


## Cells [param unit] could attack from any cell it can stop on in [param move_range].
static func attack_cells(state: BattleState, unit: UnitState, move_range: MoveRange) -> Dictionary[Vector2i, bool]:
	return cells_in_ranges(state.grid, move_range.stop_cells(), unit.attack_ranges())


## Cells within any of [param ranges] (Vector2i(min, max)) of any of [param origins].
static func cells_in_ranges(grid: BattleGrid, origins: Array[Vector2i], ranges: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for origin: Vector2i in origins:
		for weapon_range: Vector2i in ranges:
			for cell: Vector2i in cells_at_range(grid, origin, weapon_range.x, weapon_range.y):
				result[cell] = true
	return result


## In-bounds cells whose distance from [param origin] is within [param min_range]–[param max_range].
static func cells_at_range(grid: BattleGrid, origin: Vector2i, min_range: int, max_range: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy: int in range(-max_range, max_range + 1):
		var span: int = max_range - absi(dy)
		for dx: int in range(-span, span + 1):
			var distance: int = absi(dx) + absi(dy)
			var cell: Vector2i = origin + Vector2i(dx, dy)
			if distance >= min_range and grid.in_bounds(cell):
				result.append(cell)
	return result


static func _in_enemy_zoc(state: BattleState, unit: UnitState, cell: Vector2i) -> bool:
	for neighbor: Vector2i in state.grid.neighbors(cell):
		var occupant: UnitState = state.unit_at(neighbor)
		if occupant != null and not state.are_allied(occupant.faction_id, unit.faction_id) \
				and occupant.get_tags().has(state.ruleset.zoc_tag):
			return true
	return false
