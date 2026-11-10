class_name Toast
extends PanelContainer
## Short message at the top of the screen that fades out (proficiency
## level-ups, items received, "inventory full").

var _label := UiStyle.label("", 28)
var _queue: Array[String] = []
var _showing: bool = false


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel())
	add_child(_label)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Queues [param message]; messages show one after another.
func show_message(message: String) -> void:
	_queue.append(message)
	if not _showing:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_showing = false
		visible = false
		return
	_showing = true
	_label.text = _queue.pop_front()
	visible = true
	modulate.a = 1.0
	reset_size()
	position = Vector2((get_viewport_rect().size.x - size.x) * 0.5, 40)
	var tween: Tween = create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.finished.connect(_next)
