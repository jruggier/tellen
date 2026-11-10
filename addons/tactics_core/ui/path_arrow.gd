class_name PathArrow
extends Node2D
## Draws the movement path preview from the selected unit to the cursor.

@export var color: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var outline_color: Color = Color(0.08, 0.08, 0.12, 0.85)

var cell_size: int = 16
var _path: Array[Vector2i] = []


func set_path(path: Array[Vector2i]) -> void:
	_path = path
	queue_redraw()


func clear() -> void:
	var empty: Array[Vector2i] = []
	set_path(empty)


func _draw() -> void:
	if _path.size() < 2:
		return
	var points := PackedVector2Array()
	for cell: Vector2i in _path:
		points.append(Vector2(cell) * cell_size + Vector2.ONE * cell_size * 0.5)
	var end: Vector2 = points[points.size() - 1]
	var direction: Vector2 = (end - points[points.size() - 2]).normalized()
	var shaft := points.duplicate()
	shaft[shaft.size() - 1] = end - direction * 3.0
	draw_polyline(shaft, outline_color, 4.0)
	draw_polyline(shaft, color, 2.0)
	var side := Vector2(-direction.y, direction.x)
	var tip: Vector2 = end + direction * 2.5
	var head := PackedVector2Array([tip, end - direction * 3.0 + side * 3.5, end - direction * 3.0 - side * 3.5])
	draw_colored_polygon(head, outline_color)
	var inner := PackedVector2Array([tip - direction, end - direction * 2.2 + side * 2.2, end - direction * 2.2 - side * 2.2])
	draw_colored_polygon(inner, color)
