class_name StatBar
extends Control
## A horizontal meter for HP, EXP and similar values.
##
## Optional preview segments pulse to show a predicted change:
## [member loss_to] (HP after a forecast hit) and [member gain_to] (HP after
## a heal). [method animate_to] drains or fills the bar over time and emits
## [signal value_ticked] each time the shown value crosses a whole number
## (used for EXP tick sounds). Ticks every [member segment] units help read
## large values.

## The shown value crossed a whole number while animating.
signal value_ticked(shown: int)

@export var max_value: float = 100.0
@export var fill_color: Color = Color(0.45, 0.95, 0.55)
@export var back_color: Color = Color(0.08, 0.09, 0.12, 0.95)
@export var border_color: Color = Color(0, 0, 0, 0.9)
## Draw a faint tick every this many units (0 = none).
@export var segment: float = 0.0
## Color the fill green / yellow / red by how full it is (HP bars).
@export var color_by_ratio: bool = false

## The value currently drawn.
var value: float = 0.0
## Predicted value after a loss (drawn as a pulsing segment); -1 = none.
var loss_to: float = -1.0
## Predicted value after a gain (pulsing segment); -1 = none.
var gain_to: float = -1.0

var _tween: Tween
var _time: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(240, 18)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Sets the value and maximum at once (no animation).
func set_values(new_value: float, new_max: float) -> void:
	_stop()
	max_value = maxf(1.0, new_max)
	value = clampf(new_value, 0.0, max_value)
	queue_redraw()


## Shows a pulsing preview from the current value to [param after]
## (lower = loss, higher = gain); pass a negative value to clear.
func set_preview(after: float) -> void:
	loss_to = after if after >= 0.0 and after < value else -1.0
	gain_to = after if after > value else -1.0
	set_process(loss_to >= 0.0 or gain_to >= 0.0)
	queue_redraw()


## Moves the shown value to [param target] over [param seconds]
## (immediately when 0). Await it to wait for the end.
func animate_to(target: float, seconds: float) -> void:
	_stop()
	target = clampf(target, 0.0, max_value)
	if seconds <= 0.0 or not is_inside_tree():
		_show_value(target)
		return
	_tween = create_tween()
	_tween.tween_method(_show_value, value, target, seconds)
	await _tween.finished


## Fill color for an HP ratio (0–1).
static func hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.45, 0.95, 0.55)
	if ratio > 0.25:
		return Color(1.0, 0.8, 0.3)
	return Color(1.0, 0.4, 0.35)


func _show_value(shown: float) -> void:
	var before: int = floori(value)
	value = shown
	if floori(value) != before:
		value_ticked.emit(floori(value))
	queue_redraw()


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, border_color)
	var inner := rect.grow(-2.0)
	draw_rect(inner, back_color)
	var ratio: float = value / max_value
	var color: Color = hp_color(ratio) if color_by_ratio else fill_color
	var pulse: float = 0.45 + 0.4 * sin(_time * 6.0)
	if loss_to >= 0.0:
		var kept: float = inner.size.x * loss_to / max_value
		draw_rect(Rect2(inner.position, Vector2(kept, inner.size.y)), color)
		draw_rect(Rect2(inner.position + Vector2(kept, 0), Vector2(inner.size.x * ratio - kept, inner.size.y)), Color(1.0, 0.35, 0.3, pulse))
	else:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, inner.size.y)), color)
		if gain_to >= 0.0:
			var from_x: float = inner.size.x * ratio
			draw_rect(Rect2(inner.position + Vector2(from_x, 0), Vector2(inner.size.x * gain_to / max_value - from_x, inner.size.y)), Color(0.55, 1.0, 0.65, pulse))
	# A highlight line gives the fill some depth.
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * ratio, maxf(1.0, inner.size.y * 0.25))), Color(1, 1, 1, 0.18))
	if segment > 0.0 and max_value / segment <= 60.0:
		var step: float = inner.size.x * segment / max_value
		var x: float = step
		while x < inner.size.x - 0.5:
			draw_line(inner.position + Vector2(x, 0), inner.position + Vector2(x, inner.size.y), Color(0, 0, 0, 0.35), 1.0)
			x += step
