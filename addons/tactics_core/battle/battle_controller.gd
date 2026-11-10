class_name BattleController
extends Node
## Owns the [BattleState] of a running battle and is the only place
## commands are executed.
##
## Every command goes through [method execute]: validated, applied, logged,
## then announced via [code]TacticsEvents[/code] and [signal command_executed].
## Presentation listens and animates; logic never waits for animation.

## A command was applied to the state.
signal command_executed(command: Command)
## A command was undone.
signal command_undone(command: Command)

var state: BattleState
var action_log := ActionLog.new()
var threat_map := ThreatMap.new()
var _undo_stack: Array[Command] = []


## Builds the battle state from [param map] with [param ruleset] on
## difficulty [param difficulty]. Turn 1 starts with [method start].
func setup(map: BattleMap, ruleset: Ruleset, master_seed: int, difficulty: StringName = &"normal") -> void:
	var layer: TileMapLayer = map.get_terrain_layer()
	var grid: BattleGrid = BattleGrid.from_tile_map_layer(layer, ruleset) if layer != null else BattleGrid.new()
	state = BattleState.new(ruleset, grid)
	state.map_id = map.map_id
	state.factions = map.factions.duplicate()
	state.difficulty_id = difficulty
	state.rng = SeededRng.new(master_seed)
	TacticsRng.set_rng(state.rng)
	for placement: UnitPlacement in map.placements:
		var unit: UnitState = UnitFactory.from_placement(state, placement)
		if unit == null:
			continue
		if state.grid.move_cost(placement.cell, unit.movement_type_id()) < 1:
			TacticsLog.warn("BattleController", "'%s' is placed on impassable terrain at %s" % [unit.id, placement.cell])
		state.add_unit(unit)
	ReinforcementRules.queue(state, map.reinforcements)
	state.trigger_regions = map.trigger_regions.duplicate()
	state.map_events = map.events.duplicate()
	for event: MapEvent in state.map_events:
		if event != null:
			for problem: String in event.validate():
				TacticsLog.warn("BattleController", problem)


## Starts turn 1 (first faction's phase). Returns its phase report.
func start() -> TurnManager.PhaseReport:
	var report: TurnManager.PhaseReport = TurnManager.start_battle(state)
	TacticsEvents.turn_started.emit(state.turn)
	TacticsEvents.phase_started.emit(report.faction_id, state.turn)
	return report


## Validates and applies [param command]. Returns false if it was illegal.
func execute(command: Command) -> bool:
	if not command.can_execute(state):
		TacticsLog.warn("BattleController", "Rejected illegal command: %s" % command.to_dict())
		return false
	command.execute(state)
	action_log.record(command, state)
	if command.can_undo():
		_undo_stack.append(command)
	else:
		_undo_stack.clear()
	command.emit_events(TacticsEvents)
	command_executed.emit(command)
	return true


## True if the last command can be undone (e.g. a move before acting).
func can_undo() -> bool:
	return not _undo_stack.is_empty()


## Undoes the last undoable command. Returns false if there is none.
func undo_last() -> bool:
	if _undo_stack.is_empty():
		return false
	var command: Command = _undo_stack.pop_back()
	command.undo(state)
	action_log.pop()
	command_undone.emit(command)
	return true
