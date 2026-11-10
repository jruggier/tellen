class_name PlayerInputController
extends Node
## Turns player input into commands during the player phase. It is the
## only node that reads battle input, so menus, targeting and the map never
## compete for the same key press.
##
## Flow: IDLE → (confirm on own unit) SELECTED → (confirm on a tile) MOVING
## → ACTION_MENU → Attack/Heal (WEAPON_MENU → TARGETING), Items (ITEM_MENU →
## ITEM_ACTIONS), Trade (TARGETING → TRADING) or Wait → ANIMATING →
## LEVEL_UP (if any) → IDLE. Cancel steps back; cancelling the action menu
## undoes the move unless a free action (equip, trade, discard) locked it in.
## INSPECT shows another unit's ranges. PAUSE_MENU (menu action) offers
## End Turn and the objective. DISABLED outside the player's phase.
##
## [method confirm], [method cancel], [method move_selection] and the
## cursor's cell are the inputs, so tests can drive everything without
## real input events.

signal state_changed(new_state: State)
## Emitted when an action (and its animations and level-ups) has finished.
signal action_finished
## The player asked to end the phase (end_turn action or pause menu).
signal end_turn_requested
## The player picked a pause-menu entry other than End Turn.
signal pause_option_chosen(option_id: StringName)

enum State { IDLE, SELECTED, MOVING, ACTION_MENU, WEAPON_MENU, TARGETING, ITEM_MENU, ITEM_ACTIONS, TRADING, ANIMATING, LEVEL_UP, INSPECT, PAUSE_MENU, DISABLED, CANTO, CLASS_MENU }
enum TargetMode { ATTACK, HEAL, TRADE, SIGNATURE, TALK }

var state: State = State.DISABLED
## Extra pause-menu entries ({id, text}) supplied by the battle flow.
var pause_options: Array[Dictionary] = []
## The map's objectives (for Seize / Escape actions).
var objectives: Array[Objective] = []
## Awaited before every player attack (battle quotes): (attacker, defender).
var before_attack: Callable = Callable()
## Presents a fired event's outcome (dialogue etc.): (MapEventRules.Outcome).
var present_event: Callable = Callable()
var controller: BattleController
var cursor: GridCursor
var overlay: RangeOverlay
var path_arrow: PathArrow
var camera: BattleCamera
var presenter: CombatPresenter
var menu: MenuList
var sub_menu: MenuList
var forecast_panel: ForecastPanel
var info_panel: UnitInfoPanel
var level_panel: LevelUpPanel
var toast: Toast
var trade_panel: TradePanel
## Unit id → view, for animations.
var unit_views: Dictionary[StringName, UnitView] = {}
## Faction the human controls.
var player_faction: StringName = &"player"

var _selected: UnitState = null
var _move_range: MoveRange = null
var _threat_on: bool = false
var _moved_this_selection: bool = false
## A free action (equip, discard, trade) was taken: the unit can no longer
## back out of its turn.
var _locked: bool = false
var _target_mode: TargetMode = TargetMode.ATTACK
var _targets: Array[UnitState] = []
var _target_index: int = 0
var _weapon_slot: int = 0
var _slot_choices: Array[int] = []
var _item_slot: int = 0
var _trade_partner: UnitState = null
var _show_details: bool = false
var _level_up_queue: Array[Dictionary] = []

signal _level_up_closed


func _ready() -> void:
	cursor.cell_changed.connect(_on_cursor_moved)
	menu.chosen.connect(_on_menu_chosen)
	sub_menu.chosen.connect(_on_sub_menu_chosen)
	trade_panel.trade_requested.connect(_on_trade_requested)


func get_selected() -> UnitState:
	return _selected


## Current attack/heal/trade target, or null.
func get_target() -> UnitState:
	return _targets[_target_index] if state == State.TARGETING and _target_index < _targets.size() else null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and state == State.TARGETING:
		_hover_target_under_mouse()
		return
	if state == State.DISABLED or state == State.ANIMATING or state == State.MOVING:
		return
	var handled: bool = true
	if event.is_action_pressed(&"end_turn") and not event.is_echo() and state == State.IDLE:
		end_turn_requested.emit()
	elif event.is_action_pressed(&"menu") and not event.is_echo() and state == State.IDLE:
		open_pause_menu()
	elif event.is_action_pressed(&"confirm"):
		confirm()
	elif event.is_action_pressed(&"cancel"):
		cancel()
	elif event.is_action_pressed(&"info"):
		toggle_info()
	elif event.is_action_pressed(&"toggle_threat") and not event.is_echo():
		toggle_threat()
	elif event.is_action_pressed(&"next_unit") and not event.is_echo():
		cycle_unit(1)
	elif event.is_action_pressed(&"prev_unit") and not event.is_echo():
		cycle_unit(-1)
	elif event.is_action_pressed(&"cursor_up", true):
		move_selection(Vector2i.UP)
	elif event.is_action_pressed(&"cursor_down", true):
		move_selection(Vector2i.DOWN)
	elif event.is_action_pressed(&"cursor_left", true):
		move_selection(Vector2i.LEFT)
	elif event.is_action_pressed(&"cursor_right", true):
		move_selection(Vector2i.RIGHT)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Directional input while a menu, target list or trade screen is open
## (the map cursor moves itself in the other states).
func move_selection(direction: Vector2i) -> void:
	match state:
		State.ACTION_MENU, State.WEAPON_MENU, State.ITEM_MENU, State.PAUSE_MENU, State.CLASS_MENU:
			menu.move(direction.y if direction.y != 0 else direction.x)
		State.ITEM_ACTIONS:
			sub_menu.move(direction.y if direction.y != 0 else direction.x)
		State.TARGETING:
			_cycle_target(1 if direction == Vector2i.RIGHT or direction == Vector2i.DOWN else -1)
		State.TRADING:
			trade_panel.move(direction)


## Confirm at the cursor (or on the open menu / target).
func confirm() -> void:
	var battle: BattleState = controller.state
	match state:
		State.IDLE:
			var unit: UnitState = battle.unit_at(cursor.cell)
			if unit == null:
				return
			if unit.faction_id == player_faction and unit.is_ready() and not unit.has_moved:
				_select(unit)
			else:
				_inspect(unit)
		State.SELECTED:
			var other: UnitState = battle.unit_at(cursor.cell)
			if cursor.cell == _selected.cell:
				_moved_this_selection = false
				_open_action_menu()
			elif _move_range.can_stop_at(cursor.cell):
				_move_to(cursor.cell)
			elif other != null and other != _selected and other.faction_id == player_faction and other.is_ready() and not other.has_moved:
				_select(other)
		State.ACTION_MENU, State.WEAPON_MENU, State.ITEM_MENU, State.PAUSE_MENU, State.CLASS_MENU:
			menu.accept()
		State.ITEM_ACTIONS:
			sub_menu.accept()
		State.TARGETING:
			_confirm_target()
		State.TRADING:
			trade_panel.accept()
		State.LEVEL_UP:
			_level_up_closed.emit()
		State.INSPECT:
			_deselect()
		State.CANTO:
			if cursor.cell == _selected.cell or not _move_range.can_stop_at(cursor.cell):
				if cursor.cell == _selected.cell:
					_end_turn_for_unit()
				return
			_do_canto_move(cursor.cell)


## Cancel / back.
func cancel() -> void:
	match state:
		State.SELECTED:
			var unit_cell: Vector2i = _selected.cell
			_deselect()
			cursor.set_cell(unit_cell)
		State.ACTION_MENU:
			if _locked:
				return
			if _moved_this_selection:
				if not controller.can_undo():
					return
				controller.undo_last()
				var view: UnitView = unit_views.get(_selected.id)
				if view != null:
					view.place_at(_selected.cell)
			menu.close()
			cursor.set_cell(_selected.cell)
			_select(_selected)
		State.WEAPON_MENU, State.ITEM_MENU, State.CLASS_MENU:
			_open_action_menu()
		State.ITEM_ACTIONS:
			sub_menu.close()
			_open_item_menu()
		State.TARGETING:
			_end_targeting()
			if _target_mode != TargetMode.TRADE and _target_mode != TargetMode.TALK and _slot_choices.size() > 1:
				_open_slot_menu()
			else:
				_open_action_menu()
		State.TRADING:
			if not trade_panel.cancel_pick():
				trade_panel.close()
				_open_action_menu()
		State.INSPECT, State.PAUSE_MENU:
			_deselect()
		State.CANTO:
			_end_turn_for_unit()


## Starts the player's phase: input on, cursor on the first ready unit.
func begin_player_phase() -> void:
	_deselect()
	for unit: UnitState in controller.state.units_of(player_faction):
		if unit.is_ready():
			cursor.set_cell(unit.cell)
			break


## Turns input off (other factions' phases, victory/defeat).
func disable() -> void:
	_deselect()
	_set_state(State.DISABLED)


## Pauses input during the player's phase (event dialogue) without moving the cursor.
func suspend() -> void:
	if state == State.IDLE:
		_set_state(State.DISABLED)


## Undoes [method suspend] if it is still the human faction's phase.
func resume() -> void:
	var faction: FactionData = controller.state.current_faction()
	if state == State.DISABLED and faction != null and faction.controller == FactionData.Controller.HUMAN:
		_set_state(State.IDLE)


## Opens the pause menu (End Turn plus [member pause_options]).
func open_pause_menu() -> void:
	var options: Array[Dictionary] = [{"id": &"end_turn", "text": tr("UI_END_TURN")}]
	options.append_array(pause_options)
	menu.open(options, Vector2(80, 300), tr("UI_PAUSE_TITLE"))
	_set_state(State.PAUSE_MENU)


## Expands the unit panel (map) or the forecast details (targeting).
func toggle_info() -> void:
	if state == State.TARGETING:
		_show_details = not _show_details
		_show_target()
	else:
		info_panel.expanded = not info_panel.expanded
		_show_unit_info(_info_unit())


## Shows or hides every enemy's combined range.
func toggle_threat() -> void:
	if state in [State.IDLE, State.SELECTED, State.INSPECT]:
		_threat_on = not _threat_on
		_update_threat()


## Moves the cursor to the next (or previous) ready player unit.
func cycle_unit(direction: int) -> void:
	if state != State.IDLE:
		return
	var ready: Array[UnitState] = []
	for unit: UnitState in controller.state.units_of(player_faction):
		if unit.is_ready() and not unit.has_moved:
			ready.append(unit)
	if ready.is_empty():
		return
	var index: int = -1
	for i: int in ready.size():
		if ready[i].cell == cursor.cell:
			index = i
	index = posmod(index + direction, ready.size()) if index >= 0 else (0 if direction > 0 else ready.size() - 1)
	cursor.set_cell(ready[index].cell)


# Selection and movement ---------------------------------------------------------------

func _select(unit: UnitState) -> void:
	_selected = unit
	_moved_this_selection = false
	_locked = false
	_move_range = RangeCalculator.movement(controller.state, unit)
	var move_cells: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _move_range.stop_cells():
		move_cells[cell] = true
	overlay.show_unit_ranges(move_cells, RangeCalculator.attack_cells(controller.state, unit, _move_range))
	cursor.input_enabled = true
	_set_state(State.SELECTED)
	_on_cursor_moved(cursor.cell)


func _inspect(unit: UnitState) -> void:
	_selected = unit
	var entry: ThreatMap.Entry = controller.threat_map.for_unit(controller.state, unit.id)
	overlay.show_unit_ranges(entry.move_cells, entry.attack_cells)
	_set_state(State.INSPECT)


func _deselect() -> void:
	_selected = null
	_move_range = null
	_trade_partner = null
	overlay.clear_unit_ranges()
	path_arrow.clear()
	menu.close()
	sub_menu.close()
	forecast_panel.visible = false
	trade_panel.close()
	cursor.input_enabled = true
	_update_threat()
	_set_state(State.IDLE)
	_on_cursor_moved(cursor.cell)


func _move_to(cell: Vector2i) -> void:
	var command := MoveCommand.new(_selected.id, cell)
	if not controller.execute(command):
		return
	_moved_this_selection = true
	overlay.clear_unit_ranges()
	path_arrow.clear()
	_set_state(State.MOVING)
	cursor.input_enabled = false
	var view: UnitView = unit_views.get(_selected.id)
	if view == null:
		_open_action_menu()
		return
	view.walk_finished.connect(_open_action_menu, CONNECT_ONE_SHOT)
	view.walk(command.path)


# Action menu -------------------------------------------------------------------------

func _open_action_menu() -> void:
	cursor.input_enabled = false
	cursor.set_cell(_selected.cell)
	overlay.clear_unit_ranges()
	path_arrow.clear()
	forecast_panel.visible = false
	sub_menu.close()
	var battle: BattleState = controller.state
	var options: Array[Dictionary] = []
	if AwakenCommand.new(_selected.id).can_execute(battle):
		options.append({"id": &"awaken", "text": tr("ACTION_AWAKEN")})
	if SignatureAttackCommand.available(_selected) and not _slots_with_targets(TargetMode.SIGNATURE).is_empty():
		options.append({"id": &"signature", "text": _selected.awakening.signature.get_display_name()})
	if not _slots_with_targets(TargetMode.ATTACK).is_empty():
		options.append({"id": &"attack", "text": tr("ACTION_ATTACK")})
	if not _slots_with_targets(TargetMode.HEAL).is_empty():
		options.append({"id": &"heal", "text": tr("ACTION_HEAL")})
	if not _selected.inventory.is_empty():
		options.append({"id": &"items", "text": tr("ACTION_ITEMS")})
	if not CombatContext.adjacent_allies(battle, _selected, _selected.cell).is_empty():
		options.append({"id": &"trade", "text": tr("ACTION_TRADE")})
	if not EventCommands.Talk.partners(battle, _selected, battle.map_events).is_empty():
		options.insert(0, {"id": &"talk", "text": tr("ACTION_TALK")})
	var visit: MapEvent = EventCommands.Visit.event_for(battle, _selected, battle.map_events)
	if visit != null:
		options.insert(0, {"id": &"visit", "text": tr(visit.action_label) if not visit.action_label.is_empty() else tr("ACTION_VISIT")})
	if SeizeCommand.new(_selected.id, objectives).can_execute(battle):
		options.insert(0, {"id": &"seize", "text": tr("ACTION_SEIZE")})
	if EscapeCommand.new(_selected.id, objectives).can_execute(battle):
		options.insert(0, {"id": &"escape", "text": tr("ACTION_ESCAPE")})
	if not ClassChangeRules.eligible_classes(battle, _selected).is_empty():
		options.append({"id": &"class_change", "text": tr("ACTION_CLASS_CHANGE")})
	options.append({"id": &"wait", "text": tr("ACTION_WAIT")})
	menu.open(options, _menu_position())
	_set_state(State.ACTION_MENU)
	_show_unit_info(_selected)


func _on_menu_chosen(option_id: StringName) -> void:
	match state:
		State.PAUSE_MENU:
			_deselect()
			if option_id == &"end_turn":
				end_turn_requested.emit()
			else:
				pause_option_chosen.emit(option_id)
		State.ACTION_MENU:
			_on_action(option_id)
		State.WEAPON_MENU:
			_weapon_slot = int(String(option_id))
			_start_targeting(_target_mode)
		State.ITEM_MENU:
			_item_slot = int(String(option_id))
			_open_item_actions()
		State.CLASS_MENU:
			_do_class_change(option_id)


func _on_action(action: StringName) -> void:
	match action:
		&"awaken":
			if controller.execute(AwakenCommand.new(_selected.id)):
				_locked = true
				presenter.popup_at_cell(_selected.cell, tr("POPUP_AWAKENED"), _selected.awakening.color, 6.0)
				unit_views[_selected.id].flash()
				_refresh_views()
			_open_action_menu()
		&"attack", &"heal", &"signature":
			_target_mode = {&"attack": TargetMode.ATTACK, &"heal": TargetMode.HEAL, &"signature": TargetMode.SIGNATURE}[action]
			_slot_choices = _slots_with_targets(_target_mode)
			if _slot_choices.size() == 1:
				_weapon_slot = _slot_choices[0]
				_start_targeting(_target_mode)
			else:
				_open_slot_menu()
		&"items":
			_open_item_menu()
		&"class_change":
			_open_class_menu()
		&"talk":
			_target_mode = TargetMode.TALK
			_start_targeting(TargetMode.TALK)
		&"visit":
			_do_event_command(EventCommands.Visit.new(_selected.id, controller.state.map_events))
		&"trade":
			_target_mode = TargetMode.TRADE
			_start_targeting(TargetMode.TRADE)
		&"wait":
			menu.close()
			controller.execute(WaitCommand.new(_selected.id))
			_finish_action()
		&"seize":
			menu.close()
			controller.execute(SeizeCommand.new(_selected.id, objectives))
			_finish_action()
		&"escape":
			menu.close()
			controller.execute(EscapeCommand.new(_selected.id, objectives))
			_refresh_views()
			_finish_action()


## Weapon (or staff) slots that have at least one target from the current cell.
func _slots_with_targets(mode: TargetMode) -> Array[int]:
	var result: Array[int] = []
	var slots: Array[int] = _selected.heal_slot_indices() if mode == TargetMode.HEAL else _selected.attack_slot_indices()
	for slot: int in slots:
		if not _targets_for(mode, slot).is_empty():
			result.append(slot)
	return result


func _targets_for(mode: TargetMode, slot: int) -> Array[UnitState]:
	var battle: BattleState = controller.state
	match mode:
		TargetMode.ATTACK, TargetMode.SIGNATURE:
			return CombatContext.attack_targets(battle, _selected, _selected.cell, _selected.inventory[slot].weapon())
		TargetMode.HEAL:
			return CombatContext.heal_targets(battle, _selected, _selected.cell, _selected.inventory[slot].weapon())
		TargetMode.TALK:
			return EventCommands.Talk.partners(battle, _selected, battle.map_events)
		_:
			return CombatContext.adjacent_allies(battle, _selected, _selected.cell)


func _open_slot_menu() -> void:
	var options: Array[Dictionary] = []
	for slot: int in _slot_choices:
		var weapon: WeaponData = _selected.inventory[slot].weapon()
		options.append({"id": StringName(str(slot)), "text": weapon.get_display_name(), "detail": "%d-%d" % [weapon.range_min, weapon.range_max]})
	menu.open(options, _menu_position(), tr("UI_STAFF_MENU_TITLE") if _target_mode == TargetMode.HEAL else tr("UI_WEAPON_MENU_TITLE"))
	_set_state(State.WEAPON_MENU)


# Targeting ---------------------------------------------------------------------------

func _start_targeting(mode: TargetMode) -> void:
	_target_mode = mode
	_targets = _targets_for(mode, _weapon_slot)
	if _targets.is_empty():
		_open_action_menu()
		return
	menu.close()
	_target_index = 0
	if mode == TargetMode.TRADE and _targets.size() == 1:
		_open_trade(_targets[0])
		return
	if mode == TargetMode.TALK and _targets.size() == 1:
		_do_event_command(EventCommands.Talk.new(_selected.id, _targets[0].id, controller.state.map_events))
		return
	var cells: Dictionary[Vector2i, bool] = {}
	for target: UnitState in _targets:
		cells[target.cell] = true
	if mode == TargetMode.ATTACK or mode == TargetMode.SIGNATURE:
		overlay.show_unit_ranges({}, cells)
	else:
		overlay.show_unit_ranges(cells, {})
	_set_state(State.TARGETING)
	_show_target()


func _cycle_target(direction: int) -> void:
	if _targets.is_empty():
		return
	_target_index = posmod(_target_index + direction, _targets.size())
	_show_target()


func _hover_target_under_mouse() -> void:
	var world: Vector2 = cursor.get_global_mouse_position()
	var cell := Vector2i(floori(world.x / cursor.cell_size), floori(world.y / cursor.cell_size))
	for i: int in _targets.size():
		if _targets[i].cell == cell and i != _target_index:
			_target_index = i
			_show_target()


func _show_target() -> void:
	var target: UnitState = _targets[_target_index]
	cursor.set_cell(target.cell)
	var battle: BattleState = controller.state
	match _target_mode:
		TargetMode.ATTACK, TargetMode.SIGNATURE:
			var weapon: WeaponData = _selected.inventory[_weapon_slot].weapon()
			var a: CombatParticipant = CombatContext.participant(battle, _selected, _selected.cell, weapon, target, true)
			if _target_mode == TargetMode.SIGNATURE:
				SignatureAttackCommand.apply_signature(_selected, a)
			var d: CombatParticipant = CombatContext.participant(battle, target, target.cell, target.equipped_weapon(), _selected, false)
			var rules: CombatRules = battle.ruleset.combat_rules
			var forecast: CombatForecast = CombatForecast.calculate(rules, a, d, BattleGrid.distance(_selected.cell, target.cell))
			var awaken_gain: int = battle.ruleset.awakening_rule.forecast_gain(forecast) if battle.ruleset.awakening_rule != null and _selected.awakening != null else 0
			var chain: Vector2i = ChainAttacks.preview(battle, _selected, target)
			var details: Array[Dictionary] = [rules.forecast_details(a, d), rules.forecast_details(d, a)]
			var defender_weapon: WeaponData = target.equipped_weapon()
			forecast_panel.show_forecast(forecast, {
				"attacker": {"name": _selected.get_display_name(), "color": _faction_color(_selected), "weapon": weapon.get_display_name(), "terrain": battle.grid.terrain_at(_selected.cell), "awaken_gain": awaken_gain, "chain": chain.x, "chain_count": chain.y},
				"defender": {"name": target.get_display_name(), "color": _faction_color(target), "weapon": defender_weapon.get_display_name() if defender_weapon != null else tr("UI_UNARMED"), "terrain": battle.grid.terrain_at(target.cell)},
			}, details, _show_details)
		TargetMode.HEAL:
			var staff: WeaponData = _selected.inventory[_weapon_slot].weapon()
			var power: int = battle.ruleset.combat_rules.heal_amount(CombatContext.participant(battle, _selected, _selected.cell, staff))
			var max_hp: int = target.max_hp(battle.ruleset)
			forecast_panel.show_heal(target.get_display_name(), _faction_color(target), target.current_hp, mini(max_hp, target.current_hp + power), max_hp)
		TargetMode.TRADE:
			forecast_panel.visible = false
	_show_unit_info(target)


func _confirm_target() -> void:
	var target: UnitState = _targets[_target_index]
	match _target_mode:
		TargetMode.ATTACK, TargetMode.SIGNATURE:
			_do_attack(target)
		TargetMode.HEAL:
			_do_heal(target)
		TargetMode.TRADE:
			_end_targeting()
			_open_trade(target)
		TargetMode.TALK:
			_end_targeting()
			_do_event_command(EventCommands.Talk.new(_selected.id, target.id, controller.state.map_events))


func _end_targeting() -> void:
	overlay.clear_unit_ranges()
	forecast_panel.visible = false
	_targets = []


# Actions ----------------------------------------------------------------------------

func _do_attack(target: UnitState) -> void:
	var attacker: UnitState = _selected
	var ruleset: Ruleset = controller.state.ruleset
	var attacker_cell: Vector2i = attacker.cell
	var target_cell: Vector2i = target.cell
	_end_targeting()
	_set_state(State.ANIMATING)
	if before_attack.is_valid():
		await before_attack.call(attacker, target)
	var command: AttackCommand = SignatureAttackCommand.new(attacker.id, target.id, _weapon_slot) if _target_mode == TargetMode.SIGNATURE \
		else AttackCommand.new(attacker.id, target.id, _weapon_slot)
	if not controller.execute(command):
		_deselect()
		return
	await presenter.play_combat(command.result, unit_views[attacker.id], unit_views[target.id], attacker_cell, target_cell,
		attacker.max_hp(ruleset), target.max_hp(ruleset))
	_refresh_views()
	for outcome: DefeatRules.Outcome in command.defeats:
		for item: ItemData in outcome.items_given:
			toast.show_message(tr("UI_ITEM_RECEIVED") % [controller.state.get_unit(outcome.by_unit_id).get_display_name(), item.get_display_name()])
		for item: ItemData in outcome.items_lost:
			toast.show_message(tr("UI_ITEM_LOST") % item.get_display_name())
	for effect: Dictionary in command.skill_effects:
		var owner: UnitState = controller.state.get_unit(StringName(effect["unit"]))
		if owner != null and int(effect.get("heal", 0)) > 0:
			presenter.popup_at_cell(owner.cell, "%s +%d" % [tr(str(effect.get("text", ""))), int(effect["heal"])], UiStyle.GOOD, 5.0)
	_refresh_views()
	await show_progress(command.reports.values())
	_finish_action(true)


func _do_heal(target: UnitState) -> void:
	var command := HealCommand.new(_selected.id, target.id, _weapon_slot)
	if not controller.execute(command):
		return
	_end_targeting()
	_set_state(State.ANIMATING)
	presenter.popup_at_cell(target.cell, "+%d" % command.amount, UiStyle.GOOD, 7.0)
	unit_views[target.id].animate_hp(float(target.current_hp) / maxf(1.0, target.max_hp(controller.state.ruleset)), 0.4)
	await presenter.pause(0.6)
	_refresh_views()
	await show_progress([command.report])
	_finish_action(true)


## EXP popups, proficiency toasts and level-up panels, in order. Level-up
## panels wait for confirm (also during other factions' phases); the
## previous input state is restored afterwards.
func show_progress(reports: Array) -> void:
	var battle: BattleState = controller.state
	var previous: State = state
	for entry: Variant in reports:
		var report: ProgressionService.Report = entry as ProgressionService.Report
		var unit: UnitState = battle.get_unit(report.unit_id)
		if unit == null or report.exp_gained <= 0:
			continue
		presenter.popup_at_cell(unit.cell, tr("UI_EXP_GAINED") % report.exp_gained, Color(0.6, 0.85, 1.0), 5.0)
		await presenter.pause(0.5)
		for proficiency_id: StringName in report.proficiency_ups:
			toast.show_message(tr("UI_PROFICIENCY_UP") % [unit.get_display_name(), _proficiency_name(proficiency_id), report.proficiency_ups[proficiency_id]])
		for i: int in report.level_gains.size():
			level_panel.show_level_up(unit, report.old_level + i + 1, report.level_gains[i], battle.ruleset)
			_set_state(State.LEVEL_UP)
			await _level_up_closed
			level_panel.close()
			_set_state(previous)


## Ends the unit's turn. With [param allow_canto], a unit that still has
## Canto movement may move again first.
func _finish_action(allow_canto: bool = false) -> void:
	_refresh_views()
	if allow_canto and _selected != null and CantoMoveCommand.remaining(controller.state, _selected) > 0:
		_start_canto()
		return
	_deselect()
	action_finished.emit()


func _start_canto() -> void:
	_move_range = CantoMoveCommand.range_for(controller.state, _selected)
	var cells: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _move_range.stop_cells():
		cells[cell] = true
	overlay.show_unit_ranges(cells, {})
	cursor.set_cell(_selected.cell)
	_set_state(State.CANTO)


func _do_canto_move(cell: Vector2i) -> void:
	var command := CantoMoveCommand.new(_selected.id, cell)
	if not controller.execute(command):
		return
	overlay.clear_unit_ranges()
	path_arrow.clear()
	_set_state(State.MOVING)
	var view: UnitView = unit_views.get(_selected.id)
	if view != null and view.seconds_per_cell > 0.0:
		view.walk(command.path)
		await view.walk_finished
	elif view != null:
		view.place_at(cell)
	_end_turn_for_unit()


func _end_turn_for_unit() -> void:
	_refresh_views()
	_deselect()
	action_finished.emit()


# Items ------------------------------------------------------------------------------

func _open_item_menu() -> void:
	if _selected.inventory.is_empty():
		_open_action_menu()
		return
	var options: Array[Dictionary] = []
	var equipped_slot: int = _equipped_slot()
	for i: int in _selected.inventory.size():
		var slot: InventorySlot = _selected.inventory[i]
		var detail: String = ("%d/%d" % [slot.uses, slot.consumable().uses]) if slot.uses >= 0 and slot.consumable() != null else ""
		if i == equipped_slot:
			detail = tr("UI_EQUIPPED")
		options.append({"id": StringName(str(i)), "text": slot.item.get_display_name(), "detail": detail})
	menu.open(options, _menu_position(), tr("UI_ITEMS_TITLE"))
	_set_state(State.ITEM_MENU)


## Slot index of the equipped weapon, or -1.
func _equipped_slot() -> int:
	var slots: Array[int] = _selected.attack_slot_indices()
	return slots[0] if not slots.is_empty() else -1


func _open_item_actions() -> void:
	var battle: BattleState = controller.state
	var options: Array[Dictionary] = []
	var equip := InventoryCommands.Equip.new(_selected.id, _item_slot)
	if equip.can_execute(battle) and _item_slot != _equipped_slot():
		options.append({"id": &"equip", "text": tr("ITEM_ACTION_EQUIP")})
	if InventoryCommands.Use.new(_selected.id, _item_slot).can_execute(battle):
		options.append({"id": &"use", "text": tr("ITEM_ACTION_USE")})
	options.append({"id": &"discard", "text": tr("ITEM_ACTION_DISCARD")})
	sub_menu.open(options, _menu_position() + Vector2(menu.size.x + 8, 0))
	_set_state(State.ITEM_ACTIONS)


func _on_sub_menu_chosen(option_id: StringName) -> void:
	sub_menu.close()
	match option_id:
		&"equip":
			_locked = controller.execute(InventoryCommands.Equip.new(_selected.id, _item_slot)) or _locked
			_open_item_menu()
		&"discard":
			_locked = controller.execute(InventoryCommands.Discard.new(_selected.id, _item_slot)) or _locked
			_open_item_menu()
		&"use":
			_do_use_item()


func _do_use_item() -> void:
	var command := InventoryCommands.Use.new(_selected.id, _item_slot)
	if not controller.execute(command):
		return
	menu.close()
	_set_state(State.ANIMATING)
	if command.healed > 0:
		presenter.popup_at_cell(_selected.cell, "+%d" % command.healed, UiStyle.GOOD, 7.0)
	for stat_id: StringName in command.boosts.values:
		var definition: StatDefinition = controller.state.ruleset.get_stat(stat_id)
		toast.show_message("%s  %s +%d" % [_selected.get_display_name(), definition.get_abbreviation() if definition != null else String(stat_id), command.boosts.get_value(stat_id)])
	await presenter.pause(0.6)
	_finish_action(true)


# Events (Talk / Visit) ----------------------------------------------------------------

func _do_event_command(command: Command) -> void:
	menu.close()
	if not controller.execute(command):
		_open_action_menu()
		return
	_set_state(State.ANIMATING)
	var outcome: MapEventRules.Outcome = command.get(&"outcome") as MapEventRules.Outcome
	if present_event.is_valid():
		await present_event.call(outcome)
	_finish_action()


# Class change ----------------------------------------------------------------------

func _open_class_menu() -> void:
	var battle: BattleState = controller.state
	var options: Array[Dictionary] = []
	for class_data: ClassData in ClassChangeRules.eligible_classes(battle, _selected):
		options.append({"id": class_data.id, "text": class_data.get_display_name(), "detail": battle.ruleset.get_tier_name(class_data.tier)})
	menu.open(options, _menu_position(), tr("ACTION_CLASS_CHANGE"))
	_set_state(State.CLASS_MENU)


func _do_class_change(class_id: StringName) -> void:
	var command := ClassChangeCommand.new(_selected.id, class_id)
	if not controller.execute(command):
		return
	menu.close()
	var unit: UnitState = _selected
	_set_state(State.ANIMATING)
	var faction: FactionData = controller.state.get_faction(unit.faction_id)
	unit_views[unit.id].setup(unit, faction.color if faction != null else Color.WHITE, controller.state.ruleset)
	unit_views[unit.id].flash()
	presenter.popup_at_cell(unit.cell, unit.class_data.get_display_name(), UiStyle.PANEL_BORDER, 6.0)
	await presenter.pause(0.8)
	_finish_action()


# Trading ----------------------------------------------------------------------------

func _open_trade(partner: UnitState) -> void:
	_trade_partner = partner
	menu.close()
	forecast_panel.visible = false
	trade_panel.open(_selected, partner, controller.state.ruleset)
	_set_state(State.TRADING)


func _on_trade_requested(left_slot: int, right_slot: int) -> void:
	_locked = controller.execute(InventoryCommands.Trade.new(_selected.id, left_slot, _trade_partner.id, right_slot)) or _locked
	trade_panel.refresh()


# Display helpers ---------------------------------------------------------------------

func _on_cursor_moved(cell: Vector2i) -> void:
	if camera != null:
		camera.follow(cursor.cell_center(cell))
	if (state == State.SELECTED or state == State.CANTO) and _move_range != null:
		if _move_range.can_stop_at(cell):
			path_arrow.set_path(_move_range.path_to(cell))
		else:
			path_arrow.clear()
	if state in [State.IDLE, State.SELECTED, State.INSPECT]:
		_show_unit_info(_info_unit())


func _info_unit() -> UnitState:
	if state in [State.IDLE, State.SELECTED, State.INSPECT]:
		var hovered: UnitState = controller.state.unit_at(cursor.cell)
		return hovered if hovered != null else (_selected if state == State.SELECTED else null)
	return _selected


func _show_unit_info(unit: UnitState) -> void:
	if info_panel != null:
		info_panel.show_unit(unit, controller.state)


func _update_threat() -> void:
	if _threat_on:
		overlay.show_threat(controller.threat_map.for_enemies_of(controller.state, player_faction))
	else:
		var none: Dictionary[Vector2i, bool] = {}
		overlay.show_threat(none)


func _refresh_views() -> void:
	for unit: UnitState in controller.state.all_units():
		var view: UnitView = unit_views.get(unit.id)
		if view != null:
			view.refresh(unit, controller.state.ruleset)
			if unit.is_alive():
				view.place_at(unit.cell)


func _menu_position() -> Vector2:
	var view: UnitView = unit_views.get(_selected.id)
	var anchor: Vector2 = view.get_global_transform_with_canvas().origin if view != null else Vector2(960, 540)
	var cell_screen: float = cursor.cell_size * (camera.zoom.x if camera != null else 4.0)
	return anchor + Vector2(cell_screen + 16, -cell_screen * 0.5)


func _faction_color(unit: UnitState) -> Color:
	var faction: FactionData = controller.state.get_faction(unit.faction_id)
	return faction.color.lightened(0.35) if faction != null else Color.WHITE


func _proficiency_name(proficiency_id: StringName) -> String:
	var ruleset: Ruleset = controller.state.ruleset
	var weapon_type: WeaponType = ruleset.get_weapon_type(proficiency_id)
	if weapon_type != null:
		return weapon_type.get_display_name()
	var movement_type: MovementType = ruleset.get_movement_type(proficiency_id)
	return movement_type.get_display_name() if movement_type != null else String(proficiency_id)


func _set_state(new_state: State) -> void:
	state = new_state
	cursor.input_enabled = new_state in [State.IDLE, State.SELECTED, State.INSPECT, State.CANTO]
	state_changed.emit(new_state)
