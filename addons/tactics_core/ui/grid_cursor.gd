class_name GridCursor
extends Node2D
## The map cursor: moves cell by cell with keyboard/gamepad (hold to
## repeat) or follows the mouse, and glides smoothly to its target cell.
##
## Reads the [code]cursor_up/down/left/right[/code] input actions. Owners
## set [member bounds] and listen to [signal cell_changed].

signal cell_changed(cell: Vector2i)

## Seconds a direction must be held before repeating.
@export var repeat_delay: float = 0.22
## Seconds between repeats while held.
@export var repeat_interval: float = 0.06
## Higher = snappier glide toward the target cell.
@export var glide_speed: float = 28.0
@export var color: Color = Color(1.0, 0.86, 0.3)

## Cells the cursor may visit.
var bounds: Rect2i = Rect2i(0, 0, 1, 1)
## Size of one cell in world pixels.
var cell_size: int = 16
## When false the cursor ignores input (e.g. during animations). Directions
## held while it was off don't move it until released.
var input_enabled: bool = true:
	set(value):
		if value and not input_enabled:
			_repeat.reset()
		input_enabled = value
var cell: Vector2i = Vector2i.ZERO

var _repeat := DirectionRepeat.new(0.22, 0.06)
var _time: float = 0.0


## Moves the cursor to [param target] (clamped to bounds).
func set_cell(target: Vector2i, instant: bool = false) -> void:
	var clamped := Vector2i(clampi(target.x, bounds.position.x, bounds.end.x - 1), clampi(target.y, bounds.position.y, bounds.end.y - 1))
	if instant:
		position = Vector2(clamped * cell_size)
	if clamped == cell:
		return
	cell = clamped
	cell_changed.emit(cell)


## World position of the center of [param target].
func cell_center(target: Vector2i) -> Vector2:
	return Vector2(target * cell_size) + Vector2.ONE * cell_size * 0.5


func _process(delta: float) -> void:
	_time += delta
	if input_enabled:
		_poll_directions(delta)
	var goal := Vector2(cell * cell_size)
	position = goal if position.distance_to(goal) < 0.05 else position.lerp(goal, minf(1.0, glide_speed * delta))
	queue_redraw()


func _poll_directions(delta: float) -> void:
	_repeat.delay = repeat_delay
	_repeat.interval = repeat_interval
	var step: Vector2i = _repeat.poll(delta)
	if step != Vector2i.ZERO:
		_step_to(cell + step)


func _unhandled_input(event: InputEvent) -> void:
	if input_enabled and event is InputEventMouseMotion:
		var world: Vector2 = get_global_mouse_position()
		var target := Vector2i(floori(world.x / cell_size), floori(world.y / cell_size))
		if bounds.has_point(target):
			_step_to(target)


## A player-driven move: like [method set_cell], with the cursor sound.
func _step_to(target: Vector2i) -> void:
	var before: Vector2i = cell
	set_cell(target)
	if cell != before:
		Sfx.play(&"cursor_move")


func _draw() -> void:
	var s: float = float(cell_size)
	var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
	var out: float = 0.5 + pulse * 0.75
	var arm: float = 4.0
	var outline := Color(0.1, 0.08, 0.05, 0.9)
	for pass_index: int in 2:
		var c: Color = outline if pass_index == 0 else color
		var w: float = 2.0 if pass_index == 0 else 1.0
		for corner: Vector2 in [Vector2(0, 0), Vector2(s, 0), Vector2(0, s), Vector2(s, s)]:
			var sx: float = 1.0 if corner.x == 0.0 else -1.0
			var sy: float = 1.0 if corner.y == 0.0 else -1.0
			var p: Vector2 = corner - Vector2(sx, sy) * out
			draw_line(p, p + Vector2(arm * sx, 0), c, w)
			draw_line(p, p + Vector2(0, arm * sy), c, w)
