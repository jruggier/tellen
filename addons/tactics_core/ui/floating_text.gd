class_name FloatingText
extends Node2D
## World-space popup (damage numbers, MISS, CRIT, STAGGER, +EXP) that rises
## and fades, then frees itself.

var text: String = ""
var color: Color = Color.WHITE
var world_size: float = 7.0
var zoom: float = 4.0
var duration: float = 0.8
var _age: float = 0.0


## Spawns a popup under [param parent] at [param world_position].
static func spawn(parent: Node, world_position: Vector2, popup_text: String, popup_color: Color, camera_zoom: float,
		size: float = 7.0, seconds: float = 0.8) -> FloatingText:
	var popup := FloatingText.new()
	popup.text = popup_text
	popup.color = popup_color
	popup.zoom = camera_zoom
	popup.world_size = size
	popup.duration = seconds
	popup.position = world_position
	popup.z_index = 40
	parent.add_child(popup)
	return popup


func _process(delta: float) -> void:
	_age += delta
	position.y -= delta * 10.0
	modulate.a = clampf(1.5 - 1.5 * _age / duration, 0.0, 1.0)
	queue_redraw()
	if _age >= duration:
		queue_free()


func _draw() -> void:
	var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - _age * 8.0)
	WorldText.draw_centered(self, Vector2.ZERO, text, world_size * pop, zoom, color, Color(0, 0, 0, 0.9))
