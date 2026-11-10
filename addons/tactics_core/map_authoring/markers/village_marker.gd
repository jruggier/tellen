@tool
class_name VillageMarker
extends MapMarker
## A tile a unit can Visit once: plays a scene and/or gives items.

@export var dialogue_id: StringName = &""
@export var give_items: Array[ItemData] = []
@export var set_flags: Array[String] = []
## Visit only while this flag is set (empty = always).
@export var required_flag: String = ""
## Event id (empty = generated from the node name).
@export var event_id: StringName = &""


func _init() -> void:
	marker_color = Color(0.95, 0.75, 0.4)


func action_label() -> String:
	return "ACTION_VISIT"


func map_event() -> MapEvent:
	var result := MapEvent.new()
	result.id = event_id if event_id != &"" else StringName("visit_%s" % name.to_snake_case())
	result.trigger = MapEvent.Trigger.VISIT
	result.cell = get_cell()
	result.dialogue_id = dialogue_id
	result.give_items = give_items.duplicate()
	result.set_flags = set_flags.duplicate()
	result.required_flag = required_flag
	result.action_label = action_label()
	return result


func validate_marker() -> PackedStringArray:
	if dialogue_id == &"" and give_items.is_empty() and set_flags.is_empty():
		return PackedStringArray(["%s: does nothing (no dialogue, items or flags)" % describe()])
	return PackedStringArray()


func _draw_gizmo(s: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(2, 8), Vector2(8, 2), Vector2(14, 8)]), marker_color)
	draw_rect(Rect2(Vector2(4, 8), Vector2(8, 6)), Color(marker_color, 0.7))
