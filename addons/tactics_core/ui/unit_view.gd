class_name UnitView
extends Node2D
## Placeholder map sprite for a unit: a faction-colored block with the
## class initial and an HP strip. Greyed out once the unit has acted.
##
## Uses the class's [member ClassData.map_sprite] instead when one is set,
## so real art drops in through data without code changes.

signal walk_finished

var unit_id: StringName
var cell_size: int = 16
## Camera zoom, for crisp lettering.
var zoom: float = 4.0
## Seconds per cell when walking; 0 = instant.
var seconds_per_cell: float = 0.07

var _color: Color = Color.WHITE
var _letter: String = "?"
var _sprite: Texture2D = null
var _hp_ratio: float = 1.0
var _acted: bool = false
var _tween: Tween


## Reads display data from [param unit]; [param faction_color] tints it.
func setup(unit: UnitState, faction_color: Color, ruleset: Ruleset) -> void:
	unit_id = unit.id
	_color = faction_color
	var class_name_text: String = unit.class_data.get_display_name() if unit.class_data != null else "?"
	_letter = class_name_text.left(1).to_upper()
	_sprite = unit.class_data.map_sprite if unit.class_data != null else null
	position = Vector2(unit.cell * cell_size)
	refresh(unit, ruleset)


## Updates HP and acted state from [param unit].
func refresh(unit: UnitState, ruleset: Ruleset) -> void:
	_hp_ratio = clampf(float(unit.current_hp) / maxf(1.0, unit.max_hp(ruleset)), 0.0, 1.0)
	_acted = unit.has_acted
	visible = unit.is_alive()
	queue_redraw()


## Snaps to [param cell] immediately.
func place_at(cell: Vector2i) -> void:
	if _tween != null:
		_tween.kill()
	position = Vector2(cell * cell_size)


## Walks along [param path]; emits [signal walk_finished] at the end.
func walk(path: Array[Vector2i]) -> void:
	if _tween != null:
		_tween.kill()
	if seconds_per_cell <= 0.0 or path.size() < 2:
		if not path.is_empty():
			position = Vector2(path.back() * cell_size)
		walk_finished.emit.call_deferred()
		return
	_tween = create_tween()
	for i: int in range(1, path.size()):
		_tween.tween_property(self, "position", Vector2(path[i] * cell_size), seconds_per_cell)
	_tween.finished.connect(func() -> void: walk_finished.emit())


func _draw() -> void:
	var s: float = float(cell_size)
	var body: Color = _color.lerp(Color(0.45, 0.45, 0.48), 0.7) if _acted else _color
	if _sprite != null:
		draw_texture_rect(_sprite, Rect2(Vector2.ZERO, Vector2(s, s)), false, Color(0.55, 0.55, 0.55) if _acted else Color.WHITE)
	else:
		var rect := Rect2(Vector2(2, 1), Vector2(s - 4, s - 4))
		draw_rect(Rect2(rect.position + Vector2(0, 1), rect.size), Color(0, 0, 0, 0.35))
		draw_rect(rect, body)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), body.lightened(0.25))
		draw_rect(rect, body.darkened(0.55), false, 1.0)
		WorldText.draw_centered(self, rect.get_center() + Vector2(0, -0.5), _letter, 8.0, zoom, Color.WHITE, body.darkened(0.6))
	var bar := Rect2(Vector2(2, s - 2), Vector2(s - 4, 1.5))
	draw_rect(bar, Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hp_ratio, bar.size.y)), Color(0.35, 0.9, 0.45) if _hp_ratio > 0.5 else Color(0.95, 0.75, 0.2) if _hp_ratio > 0.25 else Color(0.95, 0.3, 0.25))
