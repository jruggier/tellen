class_name PlayerInputController
extends Node
## Turns player input into commands during the player phase.
##
## States:
## [br]- IDLE: confirm on a ready player unit selects it; on any other unit
##   shows its ranges (inspect).
## [br]- SELECTED: ranges and path preview shown; confirm on a reachable cell
##   moves there (or on the unit's own cell, stays); cancel deselects.
## [br]- MOVING: the move animation plays; input is ignored.
## [br]- MOVED: confirm = Wait (until the M3 action menu); cancel undoes the move.
## [br]- INSPECT: another unit's ranges are shown; confirm/cancel closes.
##
## [method confirm], [method cancel] and the cursor's cell are the only
## inputs, so tests can drive the controller without real input events.

signal state_changed(new_state: State)

enum State { IDLE, SELECTED, MOVING, MOVED, INSPECT }

var state: State = State.IDLE
var controller: BattleController
var cursor: GridCursor
var overlay: RangeOverlay
var path_arrow: PathArrow
var camera: BattleCamera
## Unit id → view, for animations.
var unit_views: Dictionary[StringName, UnitView] = {}
## Faction the human controls.
var player_faction: StringName = &"player"

var _selected: UnitState = null
var _move_range: MoveRange = null
var _threat_on: bool = false
var _moved_this_selection: bool = false


func _ready() -> void:
	cursor.cell_changed.connect(_on_cursor_moved)


func get_selected() -> UnitState:
	return _selected


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"confirm"):
		confirm()
	elif event.is_action_pressed(&"cancel"):
		cancel()
	elif event.is_action_pressed(&"toggle_threat"):
		toggle_threat()
	elif event.is_action_pressed(&"next_unit"):
		cycle_unit(1)
	elif event.is_action_pressed(&"prev_unit"):
		cycle_unit(-1)
	else:
		return
	get_viewport().set_input_as_handled()


## Confirm at the cursor's cell.
func confirm() -> void:
	var cell: Vector2i = cursor.cell
	var battle: BattleState = controller.state
	match state:
		State.IDLE:
			var unit: UnitState = battle.unit_at(cell)
			if unit == null:
				return
			if unit.faction_id == player_faction and unit.is_ready() and not unit.has_moved:
				_select(unit)
			else:
				_inspect(unit)
		State.SELECTED:
			var other: UnitState = battle.unit_at(cell)
			if cell == _selected.cell:
				_moved_this_selection = false
				_enter_moved()
			elif _move_range.can_stop_at(cell):
				_move_to(cell)
			elif other != null and other != _selected and other.faction_id == player_faction and other.is_ready() and not other.has_moved:
				_select(other)
		State.MOVED:
			controller.execute(WaitCommand.new(_selected.id))
			_refresh_view(_selected)
			_deselect()
		State.INSPECT:
			_deselect()


## Cancel / back.
func cancel() -> void:
	match state:
		State.SELECTED:
			var unit_cell: Vector2i = _selected.cell
			_deselect()
			cursor.set_cell(unit_cell)
		State.MOVED:
			if _moved_this_selection and controller.undo_last():
				var view: UnitView = unit_views.get(_selected.id)
				if view != null:
					view.place_at(_selected.cell)
			cursor.set_cell(_selected.cell)
			_select(_selected)
		State.INSPECT:
			_deselect()


## Shows or hides every enemy's combined range.
func toggle_threat() -> void:
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


func _select(unit: UnitState) -> void:
	_selected = unit
	_moved_this_selection = false
	_move_range = RangeCalculator.movement(controller.state, unit)
	var move_cells: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _move_range.stop_cells():
		move_cells[cell] = true
	overlay.show_unit_ranges(move_cells, RangeCalculator.attack_cells(controller.state, unit, _move_range))
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
	overlay.clear_unit_ranges()
	path_arrow.clear()
	_update_threat()
	_set_state(State.IDLE)


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
		_finish_move()
		return
	view.walk_finished.connect(_finish_move, CONNECT_ONE_SHOT)
	view.walk(command.path)


func _finish_move() -> void:
	cursor.input_enabled = true
	cursor.set_cell(_selected.cell)
	_enter_moved()


func _enter_moved() -> void:
	overlay.clear_unit_ranges()
	path_arrow.clear()
	_update_threat()
	_set_state(State.MOVED)


func _on_cursor_moved(cell: Vector2i) -> void:
	if camera != null:
		camera.follow(cursor.cell_center(cell))
	if state == State.SELECTED and _move_range != null:
		if _move_range.can_stop_at(cell):
			path_arrow.set_path(_move_range.path_to(cell))
		else:
			path_arrow.clear()


func _update_threat() -> void:
	if _threat_on:
		overlay.show_threat(controller.threat_map.for_enemies_of(controller.state, player_faction))
	else:
		overlay.show_threat({})


func _refresh_view(unit: UnitState) -> void:
	var view: UnitView = unit_views.get(unit.id)
	if view != null:
		view.refresh(unit, controller.state.ruleset)


func _set_state(new_state: State) -> void:
	state = new_state
	state_changed.emit(new_state)
