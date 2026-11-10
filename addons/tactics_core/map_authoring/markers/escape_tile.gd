@tool
class_name EscapeTile
extends ObjectiveTileMarker
## An escape tile. All escape tiles on a map form one Escape objective;
## the highest [member count] among them is how many units must escape.

@export_range(1, 99) var count: int = 1


func _init() -> void:
	marker_color = Color(0.5, 1.0, 0.5)


func objective() -> Objective:
	return null


func _draw_gizmo(s: float) -> void:
	draw_rect(Rect2(Vector2(0.5, 0.5), Vector2(s - 1, s - 1)), marker_color, false, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(4, 4), Vector2(12, 8), Vector2(4, 12)]), Color(marker_color, 0.8))
