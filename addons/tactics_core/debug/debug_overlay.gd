class_name DebugOverlay
extends Node2D
## Battle debug overlay, toggled with the [code]debug_overlay[/code] action
## (F3). Debug builds only (spec §14, §2a.7).
##
## On the map: each cell's coordinates and its movement cost for the
## movement type being inspected (× = impassable). In the corner: RNG seed,
## cursor cell, terrain, inspected movement type and state version.
## Extension point: AI score display (M4) draws through [method set_cell_notes].

var battle: BattleScene
var zoom: float = 4.0
var cell_size: int = 16

var _info: Label
var _movement_type_id: StringName = &"foot"
var _notes: Dictionary[Vector2i, String] = {}


func _ready() -> void:
	visible = false
	z_index = 50
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_info = Label.new()
	_info.position = Vector2(24, 24)
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 6)
	layer.add_child(_info)
	_info.visible = false
	battle.cursor.cell_changed.connect(func(_c: Vector2i) -> void: _refresh())
	battle.input.state_changed.connect(func(_s: PlayerInputController.State) -> void: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	_info.visible = visible
	_refresh()


## Text to show on cells (e.g. AI scores); empty dictionary clears.
func set_cell_notes(notes: Dictionary[Vector2i, String]) -> void:
	_notes = notes
	queue_redraw()


## Movement type whose costs are displayed.
func get_movement_type_id() -> StringName:
	return _movement_type_id


func _refresh() -> void:
	if not visible:
		return
	var state: BattleState = battle.controller.state
	var focus: UnitState = battle.input.get_selected()
	if focus == null:
		focus = state.unit_at(battle.cursor.cell)
	if focus != null:
		_movement_type_id = focus.movement_type_id()
	elif not state.ruleset.movement_types.is_empty():
		_movement_type_id = state.ruleset.movement_types[0].id
	var terrain: TerrainData = state.grid.terrain_at(battle.cursor.cell)
	_info.text = "\n".join(PackedStringArray([
		"DEBUG (F3)",
		"Seed: %d" % state.rng.get_master_seed(),
		"Cursor: %s  %s" % [battle.cursor.cell, terrain.id if terrain != null else &"(void)"],
		"Costs for: %s%s" % [_movement_type_id, ("  (%s)" % focus.id) if focus != null else ""],
		"Turn %d  phase %d  state v%d" % [state.turn, state.phase_index, state.version],
	]))
	queue_redraw()


func _draw() -> void:
	if battle == null or battle.controller == null:
		return
	var grid: BattleGrid = battle.controller.state.grid
	var rect: Rect2i = grid.get_rect()
	var s: float = float(cell_size)
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var origin := Vector2(cell) * s
			var cost: int = grid.move_cost(cell, _movement_type_id)
			var cost_text: String = str(cost) if cost > 0 else "×"
			var cost_color: Color = Color.WHITE if cost == 1 else Color(1, 0.85, 0.4) if cost > 1 else Color(1, 0.4, 0.4)
			WorldText.draw_centered(self, origin + Vector2(s * 0.5, s * 0.58), cost_text, 7.0, zoom, cost_color, Color.BLACK)
			WorldText.draw_centered(self, origin + Vector2(s * 0.5, 2.5), "%d,%d" % [x, y], 3.0, zoom, Color(0.8, 0.9, 1.0, 0.85), Color.BLACK)
			if _notes.has(cell):
				WorldText.draw_centered(self, origin + Vector2(s * 0.5, s - 2.5), _notes[cell], 3.5, zoom, Color(0.6, 1.0, 0.6), Color.BLACK)
