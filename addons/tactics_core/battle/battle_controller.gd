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


## Builds the battle state from [param map] with [param ruleset].
## Unit ids come from placements, else the unit/class id with a counter.
func setup(map: BattleMap, ruleset: Ruleset, master_seed: int) -> void:
	var layer: TileMapLayer = map.get_terrain_layer()
	var grid: BattleGrid = BattleGrid.from_tile_map_layer(layer, ruleset) if layer != null else BattleGrid.new()
	state = BattleState.new(ruleset, grid)
	state.map_id = map.map_id
	state.factions = map.factions.duplicate()
	state.rng = SeededRng.new(master_seed)
	TacticsRng.set_rng(state.rng)
	var counters: Dictionary[StringName, int] = {}
	for placement: UnitPlacement in map.placements:
		var problems: PackedStringArray = placement.validate()
		if not problems.is_empty():
			for problem: String in problems:
				TacticsLog.warn("BattleController", problem)
			continue
		if state.get_faction(placement.faction_id) == null:
			TacticsLog.warn("BattleController", "Placement at %s uses faction '%s', which the map does not list" % [placement.cell, placement.faction_id])
			continue
		var unit_id: StringName = placement.unit_id
		if unit_id == &"":
			var base: StringName = placement.unit_data.id if placement.unit_data != null else placement.class_data.id
			counters[base] = counters.get(base, 0) + 1
			unit_id = base if placement.unit_data != null and counters[base] == 1 else StringName("%s_%d" % [base, counters[base]])
		var unit: UnitState
		if placement.unit_data != null:
			unit = UnitState.from_unit_data(unit_id, placement.unit_data, ruleset, placement.faction_id, placement.cell)
		else:
			unit = UnitState.generic(unit_id, placement.class_data, placement.level, ruleset, placement.faction_id, placement.cell, placement.items, &"normal", placement.drops)
		unit.is_boss = placement.is_boss
		if placement.unit_data != null and not placement.drops.is_empty():
			for item: ItemData in placement.drops:
				unit.inventory.append(InventorySlot.of(item, true))
		if state.grid.move_cost(placement.cell, unit.movement_type_id()) < 1:
			TacticsLog.warn("BattleController", "'%s' is placed on impassable terrain at %s" % [unit_id, placement.cell])
		state.add_unit(unit)


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
