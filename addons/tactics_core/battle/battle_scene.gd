class_name BattleScene
extends Node
## Assembles a playable battle: the map, battle state, map visuals, camera,
## HUD and player input.
##
## Set [member map_scene] (or let a [BattleMap] run with F6 host itself
## here). Builds its node tree in code:
## [codeblock]
## BattleScene
## ├── BattleController
## ├── World (Node2D, source-pixel space)
## │   ├── <map>  ├── RangeOverlay  ├── PathArrow  ├── Units  └── GridCursor
## ├── BattleCamera
## ├── HUD (CanvasLayer): TerrainPanel, hint line
## ├── PlayerInputController
## └── (debug builds) DebugOverlay inside World, toggled with F3
## [/codeblock]

## The map to play when not hosted by a running BattleMap.
@export var map_scene: PackedScene
## RNG seed for the battle; 0 picks a random seed.
@export var battle_seed: int = 0
## Seconds per cell for unit movement; 0 = instant.
@export var move_seconds_per_cell: float = 0.07

## Set by [BattleMap] when a map scene is run directly.
var map_instance: BattleMap
var controller: BattleController
var world: Node2D
var overlay: RangeOverlay
var path_arrow: PathArrow
var units_layer: Node2D
var cursor: GridCursor
var camera: BattleCamera
var input: PlayerInputController
var hud: CanvasLayer
var terrain_panel: TerrainPanel
var hint_label: Label
var unit_views: Dictionary[StringName, UnitView] = {}
## Debug overlay (null in release builds).
var debug_overlay: DebugOverlay


func _ready() -> void:
	var ruleset: Ruleset = RulesetProvider.get_ruleset()
	if map_instance == null:
		if map_scene == null:
			TacticsLog.error("BattleScene", "No map_scene set")
			return
		map_instance = map_scene.instantiate() as BattleMap
		if map_instance == null:
			TacticsLog.error("BattleScene", "map_scene root must be a BattleMap")
			return
	var seed: int = battle_seed if battle_seed != 0 else randi()
	controller = BattleController.new()
	controller.name = "BattleController"
	add_child(controller)
	controller.setup(map_instance, ruleset, seed)
	_build_world(ruleset)
	_build_hud()
	_build_input()
	if OS.is_debug_build():
		debug_overlay = DebugOverlay.new()
		debug_overlay.name = "DebugOverlay"
		debug_overlay.battle = self
		debug_overlay.zoom = float(ruleset.tile_display_scale)
		debug_overlay.cell_size = ruleset.tile_source_size
		world.add_child(debug_overlay)
	var start: Vector2i = _first_player_cell()
	cursor.set_cell(start, true)
	camera.snap_to(cursor.cell_center(start))
	_on_cursor_moved(start)
	TacticsEvents.battle_started.emit(controller.state.map_id)


func _build_world(ruleset: Ruleset) -> void:
	var cell_px: int = ruleset.tile_source_size
	var zoom: float = float(ruleset.tile_display_scale)
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	world.add_child(map_instance)
	overlay = RangeOverlay.new()
	overlay.name = "RangeOverlay"
	overlay.cell_size = cell_px
	world.add_child(overlay)
	path_arrow = PathArrow.new()
	path_arrow.name = "PathArrow"
	path_arrow.cell_size = cell_px
	world.add_child(path_arrow)
	units_layer = Node2D.new()
	units_layer.name = "Units"
	world.add_child(units_layer)
	for unit: UnitState in controller.state.all_units():
		var view := UnitView.new()
		view.name = String(unit.id)
		view.cell_size = cell_px
		view.zoom = zoom
		view.seconds_per_cell = move_seconds_per_cell
		var faction: FactionData = controller.state.get_faction(unit.faction_id)
		view.setup(unit, faction.color if faction != null else Color.WHITE, ruleset)
		units_layer.add_child(view)
		unit_views[unit.id] = view
	cursor = GridCursor.new()
	cursor.name = "GridCursor"
	cursor.cell_size = cell_px
	cursor.bounds = controller.state.grid.get_rect()
	world.add_child(cursor)
	camera = BattleCamera.new()
	camera.name = "BattleCamera"
	add_child(camera)
	camera.configure(controller.state.grid.get_rect(), cell_px, zoom)
	camera.make_current()


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	hud.add_child(margin)
	terrain_panel = TerrainPanel.new()
	terrain_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	terrain_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	terrain_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(terrain_panel)
	hint_label = Label.new()
	hint_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	hint_label.size_flags_vertical = Control.SIZE_SHRINK_END
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint_label.add_theme_constant_override("outline_size", 6)
	margin.add_child(hint_label)


func _build_input() -> void:
	input = PlayerInputController.new()
	input.name = "PlayerInputController"
	input.controller = controller
	input.cursor = cursor
	input.overlay = overlay
	input.path_arrow = path_arrow
	input.camera = camera
	input.unit_views = unit_views
	input.player_faction = _player_faction()
	add_child(input)
	input.state_changed.connect(func(_s: PlayerInputController.State) -> void: _update_hint())
	cursor.cell_changed.connect(_on_cursor_moved)
	_update_hint()


func _on_cursor_moved(cell: Vector2i) -> void:
	terrain_panel.show_terrain(controller.state.grid.terrain_at(cell))


func _update_hint() -> void:
	var keys: Dictionary[PlayerInputController.State, String] = {
		PlayerInputController.State.IDLE: "UI_HINT_IDLE",
		PlayerInputController.State.SELECTED: "UI_HINT_SELECTED",
		PlayerInputController.State.MOVING: "",
		PlayerInputController.State.MOVED: "UI_HINT_MOVED",
		PlayerInputController.State.INSPECT: "UI_HINT_INSPECT",
	}
	var key: String = keys[input.state]
	hint_label.text = tr(key) if not key.is_empty() else ""


func _player_faction() -> StringName:
	for faction: FactionData in controller.state.factions:
		if faction.controller == FactionData.Controller.HUMAN:
			return faction.id
	return &"player"


func _first_player_cell() -> Vector2i:
	var units: Array[UnitState] = controller.state.units_of(_player_faction())
	if not units.is_empty():
		return units[0].cell
	return controller.state.grid.get_rect().position
