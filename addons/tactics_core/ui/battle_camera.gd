class_name BattleCamera
extends Camera2D
## Battle camera: zooms the source-pixel world up to screen size and keeps
## the cursor away from the screen edges, clamped to the map.

## Cells of margin kept between the cursor and the screen edge.
@export var edge_margin_cells: int = 3

var cell_size: int = 16
var _map_rect := Rect2()


## [param map_cells] is the map rectangle in cells; [param scale] the zoom.
func configure(map_cells: Rect2i, cells_px: int, display_scale: float) -> void:
	cell_size = cells_px
	zoom = Vector2(display_scale, display_scale)
	_map_rect = Rect2(Vector2(map_cells.position * cell_size), Vector2(map_cells.size * cell_size))
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0
	position = _clamp_center(_map_rect.get_center())
	reset_smoothing()


## Scrolls so [param world_point] stays inside the margin.
func follow(world_point: Vector2) -> void:
	var half: Vector2 = _view_size() * 0.5
	var margin := Vector2.ONE * edge_margin_cells * cell_size
	var target: Vector2 = position
	var low: Vector2 = target - half + margin
	var high: Vector2 = target + half - margin - Vector2.ONE * cell_size
	if world_point.x < low.x:
		target.x -= low.x - world_point.x
	elif world_point.x > high.x:
		target.x += world_point.x - high.x
	if world_point.y < low.y:
		target.y -= low.y - world_point.y
	elif world_point.y > high.y:
		target.y += world_point.y - high.y
	position = _clamp_center(target)


## Jumps to [param world_point] without smoothing.
func snap_to(world_point: Vector2) -> void:
	position = _clamp_center(world_point)
	reset_smoothing()


func _view_size() -> Vector2:
	return get_viewport_rect().size / zoom


func _clamp_center(point: Vector2) -> Vector2:
	var half: Vector2 = _view_size() * 0.5
	var result: Vector2 = point
	for axis: int in 2:
		var low: float = _map_rect.position[axis] + half[axis]
		var high: float = _map_rect.end[axis] - half[axis]
		result[axis] = _map_rect.get_center()[axis] if low > high else clampf(point[axis], low, high)
	return result
