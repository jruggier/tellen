@tool
class_name MapMarker
extends Node2D
## Base for everything placed on a map in the editor (spec §12.2): snaps to
## the grid, draws an editor-only gizmo, and is hidden in the running game.
## The battle reads markers through [BattleMap].

## Gizmo color.
var marker_color: Color = Color.WHITE


func _ready() -> void:
	set_notify_transform(true)
	if not Engine.is_editor_hint():
		visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		snap_to_grid()
		queue_redraw()


## The map cell this marker sits on.
func get_cell() -> Vector2i:
	var size: int = cell_size()
	return Vector2i(floori(position.x / size), floori(position.y / size)) + _parent_cell_offset()


## Moves the marker onto [param cell].
func set_cell(cell: Vector2i) -> void:
	position = Vector2((cell - _parent_cell_offset()) * cell_size())


## Snaps the position to the top-left of the cell under it.
func snap_to_grid() -> void:
	var size: int = cell_size()
	var snapped: Vector2 = (position / size).floor() * size
	if snapped != position:
		position = snapped


## True if the marker is exactly on a cell corner.
func is_on_grid() -> bool:
	var size: int = cell_size()
	return is_equal_approx(fposmod(position.x, size), 0.0) and is_equal_approx(fposmod(position.y, size), 0.0)


## Source tile size, read from the map's terrain layer (16 if unknown).
func cell_size() -> int:
	var map: BattleMap = get_battle_map()
	if map != null:
		var layer: TileMapLayer = map.get_node_or_null(map.terrain_layer_path) as TileMapLayer
		if layer != null and layer.tile_set != null:
			return layer.tile_set.tile_size.x
	return 16


## The [BattleMap] this marker belongs to, or null.
func get_battle_map() -> BattleMap:
	var node: Node = get_parent()
	while node != null:
		if node is BattleMap:
			return node as BattleMap
		node = node.get_parent()
	return null


## Problems with this marker's settings (empty when valid).
func validate_marker() -> PackedStringArray:
	return PackedStringArray()


## Short name for validator messages.
func describe() -> String:
	return "%s '%s' at %s" % [get_script().get_global_name(), name, get_cell()]


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	_draw_gizmo(float(cell_size()))


## Subclasses draw their editor gizmo here (local coordinates, one cell = [param s]).
func _draw_gizmo(s: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), Color(marker_color, 0.35))
	draw_rect(Rect2(Vector2.ZERO, Vector2(s, s)), marker_color, false, 1.0)


## Draws small centered text in the gizmo.
func _gizmo_text(text: String, center: Vector2, size: int, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, center + Vector2(-width / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0, 0, 0, 0.8))
	draw_string(font, center + Vector2(-width / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Markers inside a parent marker (reinforcement groups) are positioned
## relative to it; this converts back to map cells.
func _parent_cell_offset() -> Vector2i:
	var parent: Node = get_parent()
	if parent is MapMarker:
		return (parent as MapMarker).get_cell()
	return Vector2i.ZERO
