@tool
class_name UnitMarker
extends MapMarker
## A unit placed on the map: a named unit, or a generic unit of a class at a
## level. Everything is set in the Inspector. When selected in the editor
## the marker previews the unit's movement (blue) and attack (red) range.

## Named unit (leave empty for a generic unit).
@export var unit_data: UnitData:
	set(value):
		unit_data = value
		_preview_dirty = true
		queue_redraw()
## Class of a generic unit.
@export var class_data: ClassData:
	set(value):
		class_data = value
		_preview_dirty = true
		queue_redraw()
@export_range(1, 99) var level: int = 1:
	set(value):
		level = value
		queue_redraw()
@export var faction_id: StringName = &"enemy"
## Inventory of a generic unit, in slot order.
@export var items: Array[ItemData] = []:
	set(value):
		items = value
		_preview_dirty = true
## Items dropped to whoever defeats this unit.
@export var drops: Array[ItemData] = []
@export var is_boss: bool = false:
	set(value):
		is_boss = value
		queue_redraw()
@export var ai_profile: AIProfile
## Units sharing a group wake together.
@export var ai_group: StringName = &""
## Stats that replace the generated ones (e.g. a slow tutorial enemy).
@export var stat_overrides: StatBlock
## Proficiency levels that replace the unit's own.
@export var proficiency_overrides: Dictionary[StringName, int] = {}
## Battle id (empty = generated).
@export var unit_id: StringName = &""

var _preview_dirty: bool = true
var _preview_move: Array[Vector2i] = []
var _preview_attack: Array[Vector2i] = []
var _was_selected: bool = false


## The placement the battle will create from this marker.
func placement() -> UnitPlacement:
	var result := UnitPlacement.new()
	result.unit_data = unit_data
	result.class_data = class_data
	result.level = level
	result.faction_id = faction_id
	result.cell = get_cell()
	result.items = items.duplicate()
	result.drops = drops.duplicate()
	result.is_boss = is_boss
	result.ai_profile = ai_profile
	result.ai_group = ai_group
	result.stat_overrides = stat_overrides
	result.proficiency_overrides = proficiency_overrides.duplicate()
	result.unit_id = unit_id
	return result


func validate_marker() -> PackedStringArray:
	var problems := PackedStringArray()
	for problem: String in placement().validate():
		problems.append("%s: %s" % [describe(), problem])
	return problems


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	var selected: bool = _is_selected()
	if selected != _was_selected:
		_was_selected = selected
		_preview_dirty = true
		queue_redraw()


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_preview_dirty = true


func _draw_gizmo(s: float) -> void:
	if _was_selected:
		_draw_range_preview(s)
	var body: Color = marker_color
	draw_rect(Rect2(Vector2(1, 1), Vector2(s - 2, s - 2)), Color(body, 0.85))
	draw_rect(Rect2(Vector2(1, 1), Vector2(s - 2, s - 2)), body.darkened(0.6), false, 1.0)
	var letter: String = "?"
	if unit_data != null:
		letter = String(unit_data.id).left(1).to_upper()
	elif class_data != null:
		letter = String(class_data.id).left(1).to_upper()
	_gizmo_text(letter, Vector2(s * 0.5, s * 0.45), 9, Color.WHITE)
	if unit_data == null:
		_gizmo_text(str(level), Vector2(s - 4, s - 3), 5, Color(1, 1, 0.7))
	if is_boss:
		draw_colored_polygon(PackedVector2Array([Vector2(3, 3), Vector2(5, 0), Vector2(7, 3), Vector2(9, 0), Vector2(11, 3), Vector2(13, 0), Vector2(13, 4), Vector2(3, 4)]), Color(1, 0.85, 0.2))


func _draw_range_preview(s: float) -> void:
	if _preview_dirty:
		_compute_preview()
	var origin: Vector2i = get_cell()
	for cell: Vector2i in _preview_attack:
		draw_rect(Rect2(Vector2(cell - origin) * s, Vector2(s, s)), Color(1, 0.2, 0.2, 0.18))
	for cell: Vector2i in _preview_move:
		draw_rect(Rect2(Vector2(cell - origin) * s, Vector2(s, s)), Color(0.3, 0.5, 1, 0.22))


func _compute_preview() -> void:
	_preview_dirty = false
	_preview_move.clear()
	_preview_attack.clear()
	var map: BattleMap = get_battle_map()
	var path: String = str(ProjectSettings.get_setting(TacticsIds.SETTING_DEFAULT_RULESET, ""))
	if map == null or path.is_empty() or (unit_data == null and class_data == null):
		return
	var ruleset: Ruleset = load(path) as Ruleset
	var layer: TileMapLayer = map.get_node_or_null(map.terrain_layer_path) as TileMapLayer
	if ruleset == null or layer == null:
		return
	var state := BattleState.new(ruleset, BattleGrid.from_tile_map_layer(layer, ruleset))
	var unit: UnitState
	if unit_data != null:
		unit = UnitState.from_unit_data(&"preview", unit_data, ruleset, faction_id, get_cell())
	else:
		unit = UnitState.generic(&"preview", class_data, level, ruleset, faction_id, get_cell(), items)
	state.add_unit(unit)
	var move_range: MoveRange = RangeCalculator.movement(state, unit)
	_preview_move = move_range.stop_cells()
	for cell: Vector2i in RangeCalculator.attack_cells(state, unit, move_range):
		if not move_range.can_stop_at(cell):
			_preview_attack.append(cell)


func _is_selected() -> bool:
	if not Engine.has_singleton(&"EditorInterface"):
		return false
	var editor: Object = Engine.get_singleton(&"EditorInterface")
	var selection: Object = editor.call(&"get_selection")
	return selection != null and (selection.call(&"get_selected_nodes") as Array).has(self)
