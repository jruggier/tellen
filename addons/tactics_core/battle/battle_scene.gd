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
## ├── HUD (CanvasLayer): TerrainPanel, UnitInfoPanel, ForecastPanel, menus,
## │   LevelUpPanel, TradePanel, Toast, turn/objective line, hint line,
## │   PhaseBanner, ObjectivePanel, ResultPanel
## ├── CombatPresenter
## ├── PlayerInputController
## ├── AIController
## ├── BattleFlow (phases, AI turns, objectives, victory/defeat)
## └── (debug builds) DebugOverlay inside World, toggled with F3
## [/codeblock]

## Project setting: roster used when a map is played without a campaign.
const SETTING_TEST_ROSTER: String = "tactics_core/maps/test_roster"
const DEFAULT_TEST_ROSTER: String = "res://game/data/units/test_roster.tres"

## The map to play when not hosted by a running BattleMap.
@export var map_scene: PackedScene
## RNG seed for the battle; 0 picks a random seed.
@export var battle_seed: int = 0
## Seconds per cell for unit movement; 0 = instant.
@export var move_seconds_per_cell: float = 0.07
## Seconds per combat strike; 0 = instant.
@export var seconds_per_strike: float = 0.45
## Phase banner duration; 0 = no banner.
@export var phase_banner_seconds: float = 1.1
## Pause between AI units; 0 = none.
@export var ai_seconds_between_units: float = 0.25
## Difficulty id for generic enemy stats (see the enemy stat rules).
@export var difficulty: StringName = &"normal"
## Dialogue characters per second; 0 = instant.

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
var info_panel: UnitInfoPanel
var forecast_panel: ForecastPanel
var menu: MenuList
var sub_menu: MenuList
var level_panel: LevelUpPanel
var trade_panel: TradePanel
var toast: Toast
var presenter: CombatPresenter
var hint_label: Label
var settings_panel: SettingsPanel
var turn_label: Label
var banner: PhaseBanner
var objective_panel: ObjectivePanel
var result_panel: ResultPanel
var flow: BattleFlow
var ai: AIController
## Tellen's rewind (snapshots before each player action).
var rewind: RewindService
var dialogue_player: DialoguePlayer
## Every dialogue scene available to this battle.
var dialogues: DialogueLibrary
## Campaign state carried between maps; a fresh one when unset.
var campaign: CampaignState
## The campaign being played (null when a map is played on its own).
var campaign_data: CampaignData
## Units the player may deploy (empty = the test roster, see
## [constant SETTING_TEST_ROSTER]).
var roster: Array[UnitData] = []
## The map's objectives and defeat conditions (empty = defaults).
var objectives: Array[Objective] = []
var defeat_conditions: Array[DefeatCondition] = []
var unit_views: Dictionary[StringName, UnitView] = {}
## Debug overlay (null in release builds).
var debug_overlay: DebugOverlay


func _ready() -> void:
	var ruleset: Ruleset = RulesetProvider.get_ruleset()
	var params: Dictionary = SceneRouter.take_params()
	if params.has("campaign"):
		campaign = params["campaign"]
		campaign_data = params.get("campaign_data", null)
		if params.has("map_path") and map_instance == null:
			map_scene = load(str(params["map_path"])) as PackedScene
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
	if roster.is_empty() and campaign != null and not campaign.roster.is_empty():
		roster = campaign.roster_units()
	if roster.is_empty():
		roster = _test_roster()
	controller.setup(map_instance, ruleset, seed, difficulty, roster)
	objectives = map_instance.get_objectives()
	defeat_conditions = map_instance.get_defeat_conditions()
	if campaign == null:
		campaign = CampaignState.new()
	controller.state.campaign = campaign
	campaign.apply_records(controller.state)
	dialogues = DialogueLibrary.load_project()
	for problem: String in dialogues.errors:
		TacticsLog.warn("Dialogue", problem)
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
	TacticsLog.info("BattleScene", "Battle '%s' started: %d units, seed %d, %s" % [controller.state.map_id, controller.state.all_units().size(), seed, difficulty])
	TacticsEvents.battle_started.emit(controller.state.map_id)
	rewind = RewindService.new(controller, ruleset.rewind_charges_per_map)
	rewind.objectives_provider = func() -> Array[Objective]: return objectives.duplicate()
	dialogue_player = DialoguePlayer.new()
	dialogue_player.name = "DialoguePlayer"
	add_child(dialogue_player)
	ai = AIController.new()
	ai.name = "AIController"
	ai.scene = self
	ai.seconds_between_units = ai_seconds_between_units
	add_child(ai)
	flow = BattleFlow.new()
	flow.name = "BattleFlow"
	flow.scene = self
	flow.ai = ai
	ai.flow = flow
	add_child(flow)
	flow.battle_finished.connect(_on_battle_finished)
	settings_panel = SettingsPanel.new()
	settings_panel.name = "SettingsPanel"
	hud.add_child(settings_panel)
	settings_panel.closed.connect(input.resume)
	apply_settings()
	TacticsEvents.settings_changed.connect(apply_settings)
	flow.start()


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
		add_unit_view(unit)
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
	var top := HBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(top)
	info_panel = UnitInfoPanel.new()
	info_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(info_panel)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	turn_label = UiStyle.label("", 26)
	turn_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	turn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	turn_label.add_theme_constant_override("outline_size", 6)
	top.add_child(turn_label)
	var spacer_right := Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer_right)
	forecast_panel = ForecastPanel.new()
	forecast_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(forecast_panel)
	menu = MenuList.new()
	menu.name = "Menu"
	hud.add_child(menu)
	sub_menu = MenuList.new()
	sub_menu.name = "SubMenu"
	hud.add_child(sub_menu)
	trade_panel = TradePanel.new()
	hud.add_child(trade_panel)
	level_panel = LevelUpPanel.new()
	hud.add_child(level_panel)
	toast = Toast.new()
	hud.add_child(toast)
	banner = PhaseBanner.new()
	banner.seconds = phase_banner_seconds
	hud.add_child(banner)
	objective_panel = ObjectivePanel.new()
	hud.add_child(objective_panel)
	result_panel = ResultPanel.new()
	hud.add_child(result_panel)
	hint_label = Label.new()
	hint_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	hint_label.size_flags_vertical = Control.SIZE_SHRINK_END
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint_label.add_theme_constant_override("outline_size", 6)
	margin.add_child(hint_label)


func _build_input() -> void:
	presenter = CombatPresenter.new()
	presenter.name = "CombatPresenter"
	presenter.seconds_per_strike = seconds_per_strike
	presenter.popup_parent = world
	presenter.zoom = camera.zoom.x
	presenter.cell_size = cursor.cell_size
	presenter.unit_views = unit_views
	add_child(presenter)
	input = PlayerInputController.new()
	input.name = "PlayerInputController"
	input.controller = controller
	input.cursor = cursor
	input.overlay = overlay
	input.path_arrow = path_arrow
	input.camera = camera
	input.unit_views = unit_views
	input.presenter = presenter
	input.menu = menu
	input.sub_menu = sub_menu
	input.forecast_panel = forecast_panel
	input.info_panel = info_panel
	input.level_panel = level_panel
	input.toast = toast
	input.trade_panel = trade_panel
	input.objectives = objectives
	input.pause_options_provider = _pause_options
	input.pause_option_chosen.connect(_on_pause_option)
	input.player_faction = _player_faction()
	add_child(input)
	input.state_changed.connect(func(_s: PlayerInputController.State) -> void: _update_hint())
	cursor.cell_changed.connect(_on_cursor_moved)
	_update_hint()


## Creates the map view for [param unit] (battle start and reinforcements).
func add_unit_view(unit: UnitState) -> void:
	if unit_views.has(unit.id):
		return
	var ruleset: Ruleset = controller.state.ruleset
	var view := UnitView.new()
	view.name = String(unit.id)
	view.cell_size = ruleset.tile_source_size
	view.zoom = float(ruleset.tile_display_scale)
	view.seconds_per_cell = move_seconds_per_cell * GameSettings.current().animation_scale()
	var faction: FactionData = controller.state.get_faction(unit.faction_id)
	view.setup(unit, faction.color if faction != null else Color.WHITE, ruleset)
	units_layer.add_child(view)
	unit_views[unit.id] = view


func _test_roster() -> Array[UnitData]:
	var path: String = str(ProjectSettings.get_setting(SETTING_TEST_ROSTER, DEFAULT_TEST_ROSTER))
	if not ResourceLoader.exists(path):
		return []
	var test: UnitRoster = load(path) as UnitRoster
	return test.units.duplicate() if test != null else []


## Re-creates [param unit]'s view (e.g. after it changes faction).
func recolor_unit_view(unit: UnitState) -> void:
	var view: UnitView = unit_views.get(unit.id)
	var faction: FactionData = controller.state.get_faction(unit.faction_id)
	if view != null:
		view.setup(unit, faction.color if faction != null else Color.WHITE, controller.state.ruleset)


## Syncs every unit view with the battle state.
func refresh_views() -> void:
	for unit: UnitState in controller.state.all_units():
		var view: UnitView = unit_views.get(unit.id)
		if view != null:
			view.refresh(unit, controller.state.ruleset)
			if unit.is_alive():
				view.place_at(unit.cell)


## "Turn N · objective (progress)" at the bottom center.
func update_turn_label() -> void:
	var state: BattleState = controller.state
	var goal: Objective = ObjectiveRules.effective_objectives(objectives)[0]
	var progress: String = goal.progress(state)
	turn_label.text = "%s %d    %s%s" % [tr("UI_TURN"), state.turn, goal.describe(), ("  (%s)" % progress) if not progress.is_empty() else ""]


func _pause_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = [{"id": &"objective", "text": tr("UI_OBJECTIVE_TITLE")}]
	if rewind != null and rewind.charges_left > 0:
		options.append({"id": &"rewind", "text": tr("UI_REWIND") % rewind.charges_left, "enabled": rewind.can_rewind()})
	options.append({"id": &"settings", "text": tr("UI_PAUSE_SETTINGS")})
	options.append({"id": &"title", "text": tr("UI_PAUSE_TITLE_SCREEN")})
	return options


## Pushes the player's settings into the presentation (animation speed,
## text speed, overlay palette, forecast details).
func apply_settings() -> void:
	var settings: GameSettings = GameSettings.current()
	var scale: float = settings.animation_scale()
	presenter.seconds_per_strike = seconds_per_strike * scale
	banner.seconds = phase_banner_seconds * maxf(scale, 0.35)
	ai.seconds_between_units = ai_seconds_between_units * scale
	for view: UnitView in unit_views.values():
		view.seconds_per_cell = move_seconds_per_cell * scale
	dialogue_player.text_speed = settings.text_speed
	overlay.use_colorblind_palette(settings.colorblind_overlays)
	input.show_details = settings.forecast_details
	_update_hint()


func _on_pause_option(option_id: StringName) -> void:
	if option_id == &"objective":
		objective_panel.show_objectives(controller.state, objectives, defeat_conditions)
	elif option_id == &"rewind":
		_open_rewind_menu()
	elif option_id == &"settings":
		input.suspend()
		settings_panel.open()
	elif option_id == &"title":
		var options: Array[Dictionary] = [{"id": &"yes", "text": tr("UI_TITLE_CONFIRM_QUIT")}, {"id": &"no", "text": tr("UI_TITLE_BACK")}]
		input.open_choice_menu(options, tr("UI_TITLE_QUIT_WARNING"), func(choice: StringName) -> void:
			if choice == &"yes":
				CampaignFlow.go_to_title())


func _open_rewind_menu() -> void:
	var options: Array[Dictionary] = []
	for i: int in range(rewind.points.size() - 1, -1, -1):
		var point: RewindService.Point = rewind.points[i]
		options.append({"id": StringName(str(i)), "text": "%s %d" % [tr("UI_TURN"), point.turn], "detail": point.actor_name})
	input.open_choice_menu(options, tr("UI_REWIND_TITLE") % rewind.charges_left, func(choice: StringName) -> void: perform_rewind(int(String(choice))))


## Rewinds to snapshot [param index] and rebuilds the screen around it.
func perform_rewind(index: int) -> void:
	var point: RewindService.Point = rewind.rewind_to(index)
	if point == null:
		return
	objectives.assign(point.objectives)
	rebuild_unit_views()
	overlay.show_warnings(ReinforcementRules.telegraphed_cells(controller.state))
	update_turn_label()
	_flash_rewind()
	input.begin_player_phase()
	toast.show_message(tr("UI_REWIND_DONE") % [point.turn, rewind.charges_left])


## Recreates every unit view from the battle state.
func rebuild_unit_views() -> void:
	for view: UnitView in unit_views.values():
		view.queue_free()
	unit_views.clear()
	for unit: UnitState in controller.state.all_units():
		add_unit_view(unit)
	refresh_views()


func _flash_rewind() -> void:
	var flash := ColorRect.new()
	flash.color = Color(0.45, 0.7, 1.0, 0.55)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	var tween: Tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.6)
	tween.finished.connect(flash.queue_free)


func _on_battle_finished(victory: bool) -> void:
	var state: BattleState = controller.state
	if victory:
		await flow.run_events(MapEvent.Trigger.MAP_END)
	var lines: PackedStringArray = [tr("UI_RESULT_TURNS") % state.turn]
	_last_victory = victory
	result_panel.show_result(victory, lines, _result_prompt(victory))


func _unhandled_input(event: InputEvent) -> void:
	if objective_panel.visible and (event.is_action_pressed(&"confirm") or event.is_action_pressed(&"cancel")):
		objective_panel.close()
		get_viewport().set_input_as_handled()
	elif result_panel.visible and event.is_action_pressed(&"confirm") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_on_result_confirmed()


var _last_victory: bool = false


func _result_prompt(victory: bool) -> String:
	if campaign_data == null:
		return tr("UI_RESULT_PROMPT")
	return tr("UI_RESULT_CONTINUE") if victory else tr("UI_RESULT_RETRY")


func _on_result_confirmed() -> void:
	result_panel.visible = false
	if campaign_data == null:
		restart()
	elif _last_victory:
		CampaignFlow.complete_chapter(campaign, campaign_data, controller.state)
	else:
		CampaignFlow.retry_chapter(campaign_data)


## Restarts this battle from the beginning.
func restart() -> void:
	var path: String = map_instance.scene_file_path if map_instance != null else ""
	if map_scene == null and not path.is_empty():
		SceneRouter.go_to(path)
	else:
		get_tree().reload_current_scene()


func _on_cursor_moved(cell: Vector2i) -> void:
	terrain_panel.show_terrain(controller.state.grid.terrain_at(cell))


func _update_hint() -> void:
	var keys: Dictionary[PlayerInputController.State, String] = {
		PlayerInputController.State.IDLE: "UI_HINT_IDLE",
		PlayerInputController.State.SELECTED: "UI_HINT_SELECTED",
		PlayerInputController.State.MOVING: "",
		PlayerInputController.State.ACTION_MENU: "UI_HINT_ACTION_MENU",
		PlayerInputController.State.WEAPON_MENU: "UI_HINT_MENU",
		PlayerInputController.State.ITEM_MENU: "UI_HINT_MENU",
		PlayerInputController.State.ITEM_ACTIONS: "UI_HINT_MENU",
		PlayerInputController.State.TARGETING: "UI_HINT_TARGETING",
		PlayerInputController.State.TRADING: "UI_HINT_TRADING",
		PlayerInputController.State.ANIMATING: "UI_HINT_ANIMATING",
		PlayerInputController.State.LEVEL_UP: "UI_HINT_LEVEL_UP",
		PlayerInputController.State.INSPECT: "UI_HINT_INSPECT",
		PlayerInputController.State.PAUSE_MENU: "UI_HINT_MENU",
		PlayerInputController.State.DISABLED: "",
		PlayerInputController.State.CANTO: "UI_HINT_CANTO",
		PlayerInputController.State.CLASS_MENU: "UI_HINT_MENU",
		PlayerInputController.State.CHOICE_MENU: "UI_HINT_MENU",
	}
	var key: String = keys.get(input.state, "")
	hint_label.text = InputHints.fill(tr(key)) if not key.is_empty() else ""


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
