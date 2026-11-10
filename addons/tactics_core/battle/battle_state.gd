class_name BattleState
extends RefCounted
## The whole battle as pure data: grid, units, factions, turn and RNG.
##
## No Nodes and no signals, so battles can run headless (tests, AI
## look-ahead, replays) and be snapshotted for rewind. Commands are the only
## things that change it; [code]BattleController[/code] runs commands and
## emits events for presentation.
##
## [member version] increases on every change so caches (threat map) know
## when to recompute.

var ruleset: Ruleset
var grid: BattleGrid
var map_id: StringName = &""
## Factions in phase order.
var factions: Array[FactionData] = []
var turn: int = 1
## Index into [member factions] of the faction whose phase it is.
var phase_index: int = 0
var rng: SeededRng = SeededRng.new(0)
## Incremented on every state change.
var version: int = 0
## Difficulty id used for generic unit stats (see the enemy stat rules).
var difficulty_id: StringName = &"normal"
## Map-local flags (events, objectives); keys are flag names.
var flags: Dictionary = {}
## Campaign-wide state (non-map flags; roster in M8). Shared, not copied.
var campaign: CampaignState = CampaignState.new()
## Map events (copied from the map).
var map_events: Array[MapEvent] = []
## Regions that fire when units stop in them (copied from the map).
var trigger_regions: Array[TriggerRegion] = []
## Reinforcement arrivals not yet spawned: {placement, turn, faction, telegraph}.
var pending_arrivals: Array[Dictionary] = []
var _id_counters: Dictionary[StringName, int] = {}

var _units: Dictionary[StringName, UnitState] = {}
var _order: Array[StringName] = []
var _occupancy: Dictionary[Vector2i, StringName] = {}


func _init(battle_ruleset: Ruleset = null, battle_grid: BattleGrid = null) -> void:
	ruleset = battle_ruleset
	grid = battle_grid


## Adds [param unit]. Returns false (and logs) on duplicate id or occupied cell.
func add_unit(unit: UnitState) -> bool:
	if _units.has(unit.id):
		TacticsLog.warn("BattleState", "Duplicate unit id '%s'" % unit.id)
		return false
	if _occupancy.has(unit.cell):
		TacticsLog.warn("BattleState", "Cell %s already holds '%s'; '%s' not placed" % [unit.cell, _occupancy[unit.cell], unit.id])
		return false
	_units[unit.id] = unit
	_order.append(unit.id)
	if unit.is_alive():
		_occupancy[unit.cell] = unit.id
	mark_changed()
	return true


## A fresh unit id: [param base] for the first named unit, else
## "base_N" with a per-base counter.
func next_unit_id(base: StringName, named: bool) -> StringName:
	_id_counters[base] = _id_counters.get(base, 0) + 1
	var candidate: StringName = base if named and _id_counters[base] == 1 else StringName("%s_%d" % [base, _id_counters[base]])
	while _units.has(candidate):
		_id_counters[base] += 1
		candidate = StringName("%s_%d" % [base, _id_counters[base]])
	return candidate


## The unit with [param unit_id], or null.
func get_unit(unit_id: StringName) -> UnitState:
	return _units.get(unit_id, null)


## The living unit on [param cell], or null.
func unit_at(cell: Vector2i) -> UnitState:
	return _units[_occupancy[cell]] if _occupancy.has(cell) else null


## All units in spawn order (including defeated ones).
func all_units() -> Array[UnitState]:
	var result: Array[UnitState] = []
	for unit_id: StringName in _order:
		result.append(_units[unit_id])
	return result


## Living units of [param faction_id] in spawn order.
func units_of(faction_id: StringName) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for unit_id: StringName in _order:
		var unit: UnitState = _units[unit_id]
		if unit.faction_id == faction_id and unit.is_alive():
			result.append(unit)
	return result


## Moves [param unit_id] to [param cell] and updates occupancy.
func move_unit(unit_id: StringName, cell: Vector2i) -> void:
	var unit: UnitState = _units[unit_id]
	if _occupancy.get(unit.cell, &"") == unit_id:
		_occupancy.erase(unit.cell)
	unit.cell = cell
	_occupancy[cell] = unit_id
	mark_changed()


## Removes a defeated unit from the map (it stays in [method all_units]).
func remove_from_map(unit_id: StringName) -> void:
	var unit: UnitState = _units[unit_id]
	if _occupancy.get(unit.cell, &"") == unit_id:
		_occupancy.erase(unit.cell)
	mark_changed()


## The faction with [param faction_id], or null.
func get_faction(faction_id: StringName) -> FactionData:
	for faction: FactionData in factions:
		if faction.id == faction_id:
			return faction
	return null


## The faction whose phase it is.
func current_faction() -> FactionData:
	return factions[phase_index] if phase_index < factions.size() else null


## True if the two factions are the same or allied (in either direction).
func are_allied(faction_a: StringName, faction_b: StringName) -> bool:
	if faction_a == faction_b:
		return true
	var a: FactionData = get_faction(faction_a)
	var b: FactionData = get_faction(faction_b)
	return (a != null and a.is_allied_with(faction_b)) or (b != null and b.is_allied_with(faction_a))


## Ends every unit's Stagger (called at the end of each phase, §5.5).
func clear_staggers() -> void:
	for unit: UnitState in _units.values():
		unit.stagger_combats = 0
	mark_changed()


## The first faction controlled by a human, or null.
func human_faction() -> FactionData:
	for faction: FactionData in factions:
		if faction.controller == FactionData.Controller.HUMAN:
			return faction
	return null


## Records that something changed.
func mark_changed() -> void:
	version += 1


## A deep copy for snapshots and look-ahead. Data resources are shared.
func copy() -> BattleState:
	var other := BattleState.new(ruleset, grid)
	other.map_id = map_id
	other.factions = factions.duplicate()
	other.turn = turn
	other.phase_index = phase_index
	other.rng = rng.duplicate_rng()
	other.version = version
	other.difficulty_id = difficulty_id
	other.flags = flags.duplicate(true)
	other.pending_arrivals = pending_arrivals.duplicate()
	other.trigger_regions = trigger_regions
	other.campaign = campaign
	other.map_events = map_events
	other._id_counters = _id_counters.duplicate()
	for unit_id: StringName in _order:
		var unit: UnitState = _units[unit_id].copy()
		other._units[unit_id] = unit
		other._order.append(unit_id)
	other._occupancy = _occupancy.duplicate()
	return other
