@tool
class_name ReinforcementGroup
extends MapMarker
## Reinforcements: put [UnitMarker]s inside this node on their arrival
## tiles. They arrive at the start of [member faction_id]'s phase on
## [member turn] and never act that phase.

@export_range(1, 999) var turn: int = 2:
	set(value):
		turn = value
		queue_redraw()
@export var faction_id: StringName = &"enemy"
## Warn the player the phase before (red "!" on the tiles).
@export var telegraph: bool = true


func _init() -> void:
	marker_color = Color(1.0, 0.55, 0.15)


## The reinforcement built from the child unit markers.
func reinforcement() -> Reinforcement:
	var result := Reinforcement.new()
	result.turn = turn
	result.faction_id = faction_id
	result.telegraph = telegraph
	var placements: Array[UnitPlacement] = []
	for child: Node in get_children():
		if child is UnitMarker:
			var placement: UnitPlacement = (child as UnitMarker).placement()
			placement.faction_id = faction_id
			placements.append(placement)
	result.placements = placements
	return result


func validate_marker() -> PackedStringArray:
	var problems := PackedStringArray()
	for problem: String in reinforcement().validate():
		problems.append("%s: %s" % [describe(), problem])
	return problems


func _draw_gizmo(s: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), Color(marker_color, 0.25))
	_gizmo_text("T%d" % turn, Vector2(s * 0.5, s * 0.5), 7, marker_color)
	for child: Node in get_children():
		if child is Node2D:
			draw_rect(Rect2((child as Node2D).position - Vector2.ONE, Vector2(s + 2, s + 2)), marker_color, false, 1.0)
