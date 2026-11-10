class_name MoveRange
extends RefCounted
## Result of a movement flood fill: every reachable cell, its cheapest cost,
## and the cheapest path to it. Produced by [Pathfinder].

## Cell the unit starts on.
var start: Vector2i = Vector2i.ZERO
## Cell → cheapest movement cost from [member start].
var costs: Dictionary[Vector2i, int] = {}
## Cell → previous cell on the cheapest path.
var parents: Dictionary[Vector2i, Vector2i] = {}
## Cells the unit may end its move on (reachable and not occupied by another unit).
var stoppable: Dictionary[Vector2i, bool] = {}


## True if the unit can pass through or stop on [param cell].
func can_reach(cell: Vector2i) -> bool:
	return costs.has(cell)


## True if the unit can end its move on [param cell].
func can_stop_at(cell: Vector2i) -> bool:
	return stoppable.has(cell)


## Cheapest cost to [param cell], or -1 if unreachable.
func cost_to(cell: Vector2i) -> int:
	return costs.get(cell, -1)


## Cheapest path from [member start] to [param cell], both included.
## Empty if [param cell] is unreachable.
func path_to(cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not costs.has(cell):
		return path
	var current: Vector2i = cell
	path.append(current)
	while current != start:
		current = parents[current]
		path.append(current)
	path.reverse()
	return path


## Reachable cells (including pass-through only), row-major order.
func reachable_cells() -> Array[Vector2i]:
	return _sorted(costs.keys())


## Cells the unit can stop on, row-major order.
func stop_cells() -> Array[Vector2i]:
	return _sorted(stoppable.keys())


static func _sorted(cells: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(cells)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return result
