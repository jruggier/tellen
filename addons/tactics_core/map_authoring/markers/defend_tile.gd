@tool
class_name DefendTile
extends ObjectiveTileMarker
## Objective: keep hostile units off this tile for [member turns] turns.

@export_range(1, 99) var turns: int = 5:
	set(value):
		turns = value
		queue_redraw()


func _init() -> void:
	marker_color = Color(0.4, 0.85, 1.0)


func _make_objective() -> Objective:
	var result := DefendTileObjective.new()
	result.cell = get_cell()
	result.turns = turns
	return result


func _draw_gizmo(s: float) -> void:
	draw_rect(Rect2(Vector2(0.5, 0.5), Vector2(s - 1, s - 1)), marker_color, false, 1.0)
	_gizmo_text("D%d" % turns, Vector2(s * 0.5, s * 0.5), 6, marker_color)
