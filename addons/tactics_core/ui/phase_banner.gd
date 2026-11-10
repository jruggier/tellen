class_name PhaseBanner
extends Control
## Full-width "Player Phase" / "Enemy Phase" banner that sweeps across the
## screen (spec §14). [method play] can be awaited.

## Total on-screen time; 0 = skip.
@export var seconds: float = 1.1

var _band := ColorRect.new()
var _label := UiStyle.label("", 72)


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 10)
	add_child(_label)
	visible = false


## Shows [param text] on a band tinted [param color]; resolves when done.
func play(text: String, color: Color) -> void:
	if seconds <= 0.0 or not is_inside_tree():
		return
	var screen: Vector2 = get_viewport_rect().size
	var height: float = 150.0
	_band.color = Color(color.darkened(0.35), 0.82)
	_band.size = Vector2(screen.x, height)
	_band.position = Vector2(0, (screen.y - height) * 0.5)
	_label.text = text
	_label.size = _band.size
	_label.position = Vector2(screen.x, _band.position.y)
	visible = true
	modulate.a = 1.0
	var fast: float = 3.0 if InputMap.has_action(&"speed_up") and Input.is_action_pressed(&"speed_up") else 1.0
	var t: float = seconds / fast
	var tween: Tween = create_tween()
	tween.tween_property(_label, "position:x", 0.0, t * 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(t * 0.45)
	tween.tween_property(self, "modulate:a", 0.0, t * 0.25)
	await tween.finished
	visible = false
