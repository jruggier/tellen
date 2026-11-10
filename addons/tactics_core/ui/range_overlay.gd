class_name RangeOverlay
extends Node2D
## Draws movement (blue), attack (red) and threat (orange) cells.
##
## Each kind also has its own pattern (dots, diagonal stripes, outline with
## corner ticks) so ranges are readable without relying on color (§2a.6).

@export var move_color: Color = Color(0.25, 0.5, 1.0, 0.42)
@export var attack_color: Color = Color(1.0, 0.25, 0.25, 0.42)
@export var threat_color: Color = Color(1.0, 0.55, 0.1, 0.85)

var cell_size: int = 16
var _move: Dictionary[Vector2i, bool] = {}
var _attack: Dictionary[Vector2i, bool] = {}
var _threat: Dictionary[Vector2i, bool] = {}


## Shows a unit's movement and attack cells (attack cells under movement
## cells are not drawn twice).
func show_unit_ranges(move_cells: Dictionary[Vector2i, bool], attack_cells: Dictionary[Vector2i, bool]) -> void:
	_move = move_cells
	_attack = {}
	for cell: Vector2i in attack_cells:
		if not move_cells.has(cell):
			_attack[cell] = true
	queue_redraw()


func clear_unit_ranges() -> void:
	_move = {}
	_attack = {}
	queue_redraw()


## Shows the threat overlay (empty dictionary hides it).
func show_threat(cells: Dictionary[Vector2i, bool]) -> void:
	_threat = cells
	queue_redraw()


func is_threat_visible() -> bool:
	return not _threat.is_empty()


func _draw() -> void:
	var s: float = float(cell_size)
	for cell: Vector2i in _threat:
		var r := Rect2(Vector2(cell) * s + Vector2(1, 1), Vector2(s - 2, s - 2))
		draw_rect(r, Color(threat_color, 0.12))
		draw_rect(r, threat_color, false, 1.0)
		for corner: Vector2 in [r.position, r.position + Vector2(r.size.x - 2, 0), r.position + Vector2(0, r.size.y - 2), r.end - Vector2(2, 2)]:
			draw_rect(Rect2(corner, Vector2(2, 2)), threat_color)
	for cell: Vector2i in _attack:
		var origin := Vector2(cell) * s
		draw_rect(Rect2(origin, Vector2(s, s)), attack_color)
		var stripe := Color(attack_color.lightened(0.5), 0.55)
		for k: int in range(-int(s) + 3, int(s), 5):
			# diagonal from bottom-left to top-right, clipped to the cell
			var a := Vector2(k, s)
			var b := Vector2(k + s, 0)
			if a.x < 0.0:
				a = Vector2(0, s + a.x)
			if b.x > s:
				b = Vector2(s, b.x - s)
			draw_line(origin + a, origin + b, stripe, 1.0)
		draw_rect(Rect2(origin, Vector2(s, s)), Color(attack_color, 0.8), false, 1.0)
	for cell: Vector2i in _move:
		var origin := Vector2(cell) * s
		draw_rect(Rect2(origin, Vector2(s, s)), move_color)
		var dot := Color(move_color.lightened(0.6), 0.6)
		for dy: int in [4, 11]:
			for dx: int in [4, 11]:
				draw_rect(Rect2(origin + Vector2(dx, dy), Vector2(1, 1)), dot)
		draw_rect(Rect2(origin, Vector2(s, s)), Color(move_color, 0.85), false, 1.0)
