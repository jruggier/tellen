@tool
class_name PlayerSpawn
extends MapMarker
## A deployment slot for the player's units. Slots fill in [member slot]
## order; a [member forced_unit] always deploys here.

@export_range(0, 99) var slot: int = 0:
	set(value):
		slot = value
		queue_redraw()
## Unit that must deploy on this slot (optional).
@export var forced_unit: UnitData:
	set(value):
		forced_unit = value
		queue_redraw()


func _init() -> void:
	marker_color = Color(0.3, 0.55, 0.95)


func _draw_gizmo(s: float) -> void:
	draw_rect(Rect2(Vector2(1, 1), Vector2(s - 2, s - 2)), Color(marker_color, 0.35))
	draw_rect(Rect2(Vector2(1, 1), Vector2(s - 2, s - 2)), marker_color, false, 1.0)
	var label: String = String(forced_unit.id).left(1).to_upper() if forced_unit != null else str(slot + 1)
	_gizmo_text(label, Vector2(s * 0.5, s * 0.5), 8, Color.WHITE)
