@tool
class_name SeizeTile
extends ObjectiveTileMarker
## Objective: the protagonist seizes this tile.


func _init() -> void:
	marker_color = Color(1.0, 0.85, 0.2)


func objective() -> Objective:
	var result := SeizeObjective.new()
	result.cell = get_cell()
	return result


func _draw_gizmo(s: float) -> void:
	draw_rect(Rect2(Vector2(0.5, 0.5), Vector2(s - 1, s - 1)), marker_color, false, 1.0)
	draw_line(Vector2(5, 13), Vector2(5, 3), marker_color, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(5, 3), Vector2(12, 5), Vector2(5, 8)]), marker_color)
