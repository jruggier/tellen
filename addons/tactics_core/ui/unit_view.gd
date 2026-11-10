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
var _staggered: bool = false
var _boss: bool = false
var _awakened: bool = false
var _awaken_color: Color = Color.WHITE
var _flash: float = 0.0
var _time: float = 0.0
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
	_staggered = unit.is_staggered()
	_boss = unit.is_boss
	_awakened = unit.awakened
	_awaken_color = unit.awakening.color if unit.awakening != null else Color.WHITE
	visible = unit.is_alive()
	modulate.a = 1.0
	queue_redraw()


## Animates the HP strip to [param ratio] over [param seconds].
func animate_hp(ratio: float, seconds: float) -> void:
	if seconds <= 0.0:
		_hp_ratio = ratio
		queue_redraw()
		return
	create_tween().tween_method(func(value: float) -> void:
		_hp_ratio = value
		queue_redraw(), _hp_ratio, ratio, seconds)


## Brief white flash when hit.
func flash() -> void:
	_flash = 1.0


## Steps toward [param target_cell] and back (an attack), over [param seconds].
func bump(target_cell: Vector2i, seconds: float) -> void:
	if seconds <= 0.0:
		return
	var home: Vector2 = position
	var toward: Vector2 = (Vector2(target_cell * cell_size) - home).normalized() * cell_size * 0.35
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", home + toward, seconds * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", home, seconds * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Fades out (defeat), then hides.
func fade_out(seconds: float) -> void:
	if seconds <= 0.0:
		visible = false
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, seconds)
	tween.finished.connect(func() -> void: visible = false)


func _process(delta: float) -> void:
	_time += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 6.0)
		queue_redraw()
	elif _staggered or _awakened:
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
	if _awakened:
		var glow: float = 0.6 + 0.4 * sin(_time * 4.0)
		draw_rect(Rect2(Vector2(1, 0), Vector2(s - 2, s - 2)), Color(_awaken_color, glow), false, 1.0)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2(2, 1), Vector2(s - 4, s - 4)), Color(1, 1, 1, _flash * 0.85))
	if _staggered:
		# spinning "dizzy" marker in the top-right corner
		var center := Vector2(s - 2.5, 2.5)
		draw_circle(center, 2.6, Color(0.1, 0.05, 0.0, 0.9))
		draw_arc(center, 1.8, _time * 5.0, _time * 5.0 + PI * 1.4, 8, Color(1.0, 0.75, 0.2), 1.0)
	if _boss:
		draw_rect(Rect2(Vector2(1, 0), Vector2(3, 3)), Color(0.95, 0.25, 0.25))
		draw_rect(Rect2(Vector2(1, 0), Vector2(3, 3)), Color(0.1, 0, 0), false, 0.5)
	var bar := Rect2(Vector2(2, s - 2), Vector2(s - 4, 1.5))
	draw_rect(bar, Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hp_ratio, bar.size.y)), Color(0.35, 0.9, 0.45) if _hp_ratio > 0.5 else Color(0.95, 0.75, 0.2) if _hp_ratio > 0.25 else Color(0.95, 0.3, 0.25))
