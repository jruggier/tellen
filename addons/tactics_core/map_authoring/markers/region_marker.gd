@tool
class_name RegionMarker
extends MapMarker
## A rectangle of cells (top-left at the marker, [member size_cells] big)
## that fires [member event] when a unit stops inside. The event's trigger
## and region are set from the marker; fill in its actions (dialogue,
## wake groups, flags...) in the Inspector.

@export var size_cells: Vector2i = Vector2i(3, 3):
	set(value):
		size_cells = Vector2i(maxi(1, value.x), maxi(1, value.y))
		queue_redraw()
## What happens (trigger and region are filled in automatically).
@export var event: MapEvent


func _init() -> void:
	marker_color = Color(0.85, 0.4, 1.0)


func map_event() -> MapEvent:
	if event == null:
		return null
	var result: MapEvent = event.duplicate() as MapEvent
	result.trigger = MapEvent.Trigger.REGION
	result.region = Rect2i(get_cell(), size_cells)
	if result.id == &"":
		result.id = StringName("region_%s" % name.to_snake_case())
	return result


func validate_marker() -> PackedStringArray:
	if event == null:
		return PackedStringArray(["%s: no event set" % describe()])
	return PackedStringArray()


func _draw_gizmo(s: float) -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(size_cells) * s)
	draw_rect(rect, Color(marker_color, 0.12))
	draw_rect(rect, marker_color, false, 1.0)
	_gizmo_text(name, Vector2(rect.size.x * 0.5, 5), 6, marker_color)
