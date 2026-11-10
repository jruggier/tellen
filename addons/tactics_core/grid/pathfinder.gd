class_name Pathfinder
extends RefCounted
## Movement flood fill (Dijkstra) over a [BattleGrid] using per-movement-type
## terrain costs (spec §7.3).
##
## The grid knows nothing about units: callers describe occupancy with
## callables, so the same search serves players, AI, previews and tests.
## Costs are small integers, so a bucket queue gives exact Dijkstra order;
## ties keep the first parent found, with neighbors visited in the grid's
## fixed order, so results are deterministic.


## Floods from [param start] with [param mov] movement points.
## [br][param can_pass] (cell → bool): false blocks entering the cell (e.g. enemies).
## [br][param can_stop] (cell → bool): false for cells the unit may pass but
## not end on (e.g. allies). The start cell is always stoppable.
## [br][param must_stop] (cell → bool, optional): entering the cell ends
## movement (e.g. zone of control).
static func flood(grid: BattleGrid, start: Vector2i, mov: int, movement_type_id: StringName,
		can_pass: Callable, can_stop: Callable, must_stop: Callable = Callable()) -> MoveRange:
	var result := MoveRange.new()
	result.start = start
	result.costs[start] = 0
	var buckets: Array[Array] = []
	for i: int in mov + 1:
		buckets.append([])
	buckets[0].append(start)
	for cost: int in mov + 1:
		var bucket: Array = buckets[cost]
		var i: int = 0
		while i < bucket.size():
			var cell: Vector2i = bucket[i]
			i += 1
			if result.costs[cell] != cost:
				continue
			if cell != start and must_stop.is_valid() and must_stop.call(cell):
				continue
			for next: Vector2i in grid.neighbors(cell):
				var step: int = grid.move_cost(next, movement_type_id)
				if step < 1:
					continue
				var next_cost: int = cost + step
				if next_cost > mov or next_cost >= result.costs.get(next, mov + 1):
					continue
				if not can_pass.call(next):
					continue
				result.costs[next] = next_cost
				result.parents[next] = cell
				buckets[next_cost].append(next)
	for cell: Vector2i in result.costs:
		if cell == start or can_stop.call(cell):
			result.stoppable[cell] = true
	return result
