class_name TurnManager
extends RefCounted
## The turn loop as pure functions on [BattleState] (spec §8.1).
##
## MapStart → PhaseStart(faction) → actions → PhaseEnd → next faction →
## after the last faction, TurnEnd and turn + 1.
## [br]Phase start: the faction's units become ready again, units on healing
## terrain recover HP, reinforcements due this phase appear (they cannot
## act this phase).
## [br]Phase end: all Stagger clears; the ending faction's units are
## refreshed (so they don't look "used" during other factions' phases).
## [br]Factions with no living units are skipped, except human factions.
##
## Extension point: awakening timers and skill phase hooks tick in
## [method begin_phase] (M5).


## What happened at the start of a phase, for presentation.
class PhaseReport:
	extends RefCounted
	var faction_id: StringName
	var turn: int
	## Unit id → HP restored by terrain.
	var healed: Dictionary[StringName, int] = {}
	## Units that arrived as reinforcements.
	var spawned: Array[StringName] = []
	## Visible skill effects from phase-start hooks.
	var skill_effects: Array[Dictionary] = []


## Starts turn 1 with the first faction's phase.
static func start_battle(state: BattleState) -> PhaseReport:
	state.turn = 1
	state.phase_index = 0
	return begin_phase(state)


## Runs phase-start effects for the current faction.
static func begin_phase(state: BattleState) -> PhaseReport:
	var report := PhaseReport.new()
	var faction: FactionData = state.current_faction()
	report.faction_id = faction.id if faction != null else &""
	report.turn = state.turn
	report.spawned = ReinforcementRules.spawn_due(state)
	for unit: UnitState in state.units_of(report.faction_id):
		unit.moved_cost = 0
		unit.canto_used = false
		if report.spawned.has(unit.id):
			continue
		unit.has_moved = false
		unit.has_acted = false
		var terrain: TerrainData = state.grid.terrain_at(unit.cell)
		var max_hp: int = unit.max_hp(state.ruleset)
		if terrain != null and terrain.heal_percent > 0 and unit.current_hp < max_hp:
			var amount: int = mini(max_hp - unit.current_hp, maxi(1, floori(max_hp * terrain.heal_percent / 100.0)))
			unit.current_hp += amount
			report.healed[unit.id] = amount
	report.skill_effects = SkillRunner.phase_start(state, report.faction_id)
	state.mark_changed()
	return report


## Ends the current phase and begins the next one (skipping factions with
## no living units, except human factions). Returns the new phase's report.
static func end_phase(state: BattleState) -> PhaseReport:
	state.clear_staggers()
	var ending: FactionData = state.current_faction()
	if ending != null:
		for unit: UnitState in state.units_of(ending.id):
			unit.has_moved = false
			unit.has_acted = false
	for attempt: int in state.factions.size():
		state.phase_index += 1
		if state.phase_index >= state.factions.size():
			state.phase_index = 0
			state.turn += 1
		if _has_phase(state, state.current_faction()):
			break
	return begin_phase(state)


## True if every unit of [param faction_id] has acted (or none remain).
static func all_acted(state: BattleState, faction_id: StringName) -> bool:
	for unit: UnitState in state.units_of(faction_id):
		if unit.is_ready():
			return false
	return true


static func _has_phase(state: BattleState, faction: FactionData) -> bool:
	if faction == null:
		return false
	if faction.controller == FactionData.Controller.HUMAN:
		return true
	return not state.units_of(faction.id).is_empty() or ReinforcementRules.has_pending(state, faction.id)
