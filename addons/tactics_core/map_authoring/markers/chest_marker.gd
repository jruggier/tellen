@tool
class_name ChestMarker
extends VillageMarker
## A chest: like a village, but the menu says "Open".


func _init() -> void:
	marker_color = Color(0.85, 0.6, 0.25)


func action_label() -> String:
	return "ACTION_OPEN"


func _draw_gizmo(s: float) -> void:
	draw_rect(Rect2(Vector2(3, 6), Vector2(10, 7)), marker_color)
	draw_rect(Rect2(Vector2(3, 6), Vector2(10, 7)), marker_color.darkened(0.6), false, 1.0)
	draw_line(Vector2(3, 9), Vector2(13, 9), marker_color.darkened(0.6), 1.0)
