class_name AIPlanner
extends RefCounted
## Plans one AI unit's turn (spec §10). Pure: reads the state, returns a
## [AIPlanner.Plan]; [AIController] executes it.
##
## Behaviors decide where the unit may stand and what it does when no
## attack is worth making:
## [br]- CHARGE: anywhere; otherwise approach the nearest hostile.
## [br]- HOLD: anywhere reachable this turn; otherwise stay.
## [br]- STATIONARY: own tile only; otherwise stay.
## [br]- AGGRO_REGION: STATIONARY while asleep, CHARGE once awake.
## [br]- GUARD: within the guard radius; otherwise return toward the guard tile.
## [br]- COWARD: CHARGE until HP falls below the flee threshold, then flee.
## [br]- HEALER: heal the most valuable wounded ally; otherwise keep safe near allies.
## [br]Ties keep the first option found; destinations are visited own tile
## first, then row by row, so plans are deterministic.

enum Action { WAIT, ATTACK, HEAL }


## What a unit will do this turn.
class Plan:
	extends RefCounted
	var unit_id: StringName
	var destination: Vector2i
	var action: Action = Action.WAIT
	var target_id: StringName = &""
	var slot: int = -1
	var score: float = 0.0
	## Destination → best attack score from there (debug overlay).
	var cell_scores: Dictionary[Vector2i, float] = {}


## Plans [param unit]'s turn.
static func plan(state: BattleState, unit: UnitState) -> Plan:
	var profile: AIProfile = unit.ai_profile if unit.ai_profile != null else AIProfile.default_profile()
	var behavior: AIProfile.Behavior = effective_behavior(state, unit)
	var move_range: MoveRange = RangeCalculator.movement(state, unit)
	var result := Plan.new()
	result.unit_id = unit.id
	result.destination = unit.cell
	var destinations: Array[Vector2i] = _destinations(unit, move_range, behavior, profile)

	if behavior == AIProfile.Behavior.HEALER:
		if _plan_heal(state, unit, destinations, profile, result):
			return result
		result.destination = _safe_cell(state, unit, move_range, false)
		return result
	if behavior == AIProfile.Behavior.COWARD:
		result.destination = _flee_cell(state, unit, move_range, profile)
		return result

	var best: AIScorer.Option = null
	for cell: Vector2i in destinations:
		for slot: int in unit.attack_slot_indices():
			for target: UnitState in CombatContext.attack_targets(state, unit, cell, unit.inventory[slot].weapon()):
				var option: AIScorer.Option = AIScorer.score_attack(state, unit, cell, target, slot, profile)
				if not result.cell_scores.has(cell) or option.score > result.cell_scores[cell]:
					result.cell_scores[cell] = option.score
				if best == null or option.score > best.score:
					best = option
	if best != null:
		result.destination = best.destination
		result.action = Action.ATTACK
		result.target_id = best.target_id
		result.slot = best.slot
		result.score = best.score
		return result

	match behavior:
		AIProfile.Behavior.CHARGE:
			result.destination = _approach(state, unit, move_range, _attack_goals(state, unit))
		AIProfile.Behavior.GUARD:
			if BattleGrid.distance(unit.cell, profile.guard_cell) > profile.guard_radius:
				var goal: Array[Vector2i] = [profile.guard_cell]
				result.destination = _approach(state, unit, move_range, goal)
	return result


## The behavior in effect right now (sleeping, fleeing and charging variants resolved).
static func effective_behavior(state: BattleState, unit: UnitState) -> AIProfile.Behavior:
	var profile: AIProfile = unit.ai_profile if unit.ai_profile != null else AIProfile.default_profile()
	match profile.behavior:
		AIProfile.Behavior.AGGRO_REGION:
			return AIProfile.Behavior.CHARGE if unit.ai_awake else AIProfile.Behavior.STATIONARY
		AIProfile.Behavior.COWARD:
			var fleeing: bool = unit.current_hp * 100 < profile.flee_hp_pct * unit.max_hp(state.ruleset)
			return AIProfile.Behavior.COWARD if fleeing else AIProfile.Behavior.CHARGE
	return profile.behavior


## Units of [param faction_id] that can still act, in §10 order: units that
## can attack this turn first, then nearest to a hostile, then spawn order.
static func turn_order(state: BattleState, faction_id: StringName) -> Array[UnitState]:
	var entries: Array[Dictionary] = []
	var index: int = 0
	for unit: UnitState in state.units_of(faction_id):
		index += 1
		if not unit.is_ready():
			continue
		entries.append({"unit": unit, "can_attack": _can_attack_this_turn(state, unit), "distance": _nearest_hostile_distance(state, unit), "index": index})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["can_attack"] != b["can_attack"]:
			return a["can_attack"]
		if a["distance"] != b["distance"]:
			return a["distance"] < b["distance"]
		return a["index"] < b["index"])
	var result: Array[UnitState] = []
	for entry: Dictionary in entries:
		result.append(entry["unit"])
	return result


# Destinations and movement ----------------------------------------------------------

static func _destinations(unit: UnitState, move_range: MoveRange, behavior: AIProfile.Behavior, profile: AIProfile) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [unit.cell]
	if behavior == AIProfile.Behavior.STATIONARY:
		return cells
	for cell: Vector2i in move_range.stop_cells():
		if cell == unit.cell:
			continue
		if behavior == AIProfile.Behavior.GUARD and BattleGrid.distance(cell, profile.guard_cell) > profile.guard_radius:
			continue
		cells.append(cell)
	return cells


## The furthest stoppable cell this turn along the cheapest path to the
## nearest of [param goals]; the unit's own cell if none is reachable.
static func _approach(state: BattleState, unit: UnitState, move_range: MoveRange, goals: Array[Vector2i]) -> Vector2i:
	if goals.is_empty():
		return unit.cell
	var far: MoveRange = RangeCalculator.movement_with_budget(state, unit, 999)
	var best_goal := Vector2i(-1, -1)
	var best_cost: int = 1 << 30
	for goal: Vector2i in goals:
		var cost: int = far.cost_to(goal)
		if cost >= 0 and cost < best_cost:
			best_cost = cost
			best_goal = goal
	if best_cost == 1 << 30:
		return unit.cell
	var destination: Vector2i = unit.cell
	var mov: int = unit.mov(state.ruleset)
	for cell: Vector2i in far.path_to(best_goal):
		if far.cost_to(cell) > mov:
			break
		if move_range.can_stop_at(cell):
			destination = cell
	return destination


## Cells from which [param unit] could attack some hostile.
static func _attack_goals(state: BattleState, unit: UnitState) -> Array[Vector2i]:
	var ranges: Array[Vector2i] = unit.attack_ranges()
	if ranges.is_empty():
		ranges = [Vector2i(1, 1)]
	var hostiles: Array[Vector2i] = []
	for other: UnitState in state.all_units():
		if other.is_alive() and not state.are_allied(other.faction_id, unit.faction_id):
			hostiles.append(other.cell)
	var goals: Array[Vector2i] = []
	for cell: Vector2i in RangeCalculator.cells_in_ranges(state.grid, hostiles, ranges):
		if state.grid.move_cost(cell, unit.movement_type_id()) > 0:
			goals.append(cell)
	goals.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return goals


# Healing, fleeing, safety --------------------------------------------------------------

static func _plan_heal(state: BattleState, unit: UnitState, destinations: Array[Vector2i], profile: AIProfile, result: Plan) -> bool:
	var danger: Dictionary[Vector2i, bool] = ThreatMap.new().for_enemies_of(state, unit.faction_id)
	var found: bool = false
	for cell: Vector2i in destinations:
		for slot: int in unit.heal_slot_indices():
			var staff: WeaponData = unit.inventory[slot].weapon()
			var power: int = state.ruleset.combat_rules.heal_amount(CombatContext.participant(state, unit, cell, staff))
			for target: UnitState in CombatContext.heal_targets(state, unit, cell, staff):
				var restored: int = mini(power, target.max_hp(state.ruleset) - target.current_hp)
				var score: float = restored + (6.0 if target.is_lord or target.is_boss else 0.0) - (8.0 * profile.w_risk if danger.has(cell) else 0.0)
				if not found or score > result.score:
					found = true
					result.score = score
					result.destination = cell
					result.action = Action.HEAL
					result.target_id = target.id
					result.slot = slot
	return found


static func _flee_cell(state: BattleState, unit: UnitState, move_range: MoveRange, profile: AIProfile) -> Vector2i:
	var danger: Dictionary[Vector2i, bool] = ThreatMap.new().for_enemies_of(state, unit.faction_id)
	var best: Vector2i = unit.cell
	var best_score: float = -INF
	var candidates: Array[Vector2i] = [unit.cell]
	candidates.append_array(move_range.stop_cells())
	for cell: Vector2i in candidates:
		var score: float = -100.0 if danger.has(cell) else 0.0
		if profile.flee_cell != Vector2i(-1, -1):
			score -= BattleGrid.distance(cell, profile.flee_cell)
		else:
			score += _nearest_hostile_distance_from(state, unit, cell)
		if score > best_score:
			best_score = score
			best = cell
	return best


## A stoppable cell out of hostile reach, close to allies when possible.
static func _safe_cell(state: BattleState, unit: UnitState, move_range: MoveRange, _approach_allies: bool) -> Vector2i:
	var danger: Dictionary[Vector2i, bool] = ThreatMap.new().for_enemies_of(state, unit.faction_id)
	var best: Vector2i = unit.cell
	var best_score: float = -INF
	var candidates: Array[Vector2i] = [unit.cell]
	candidates.append_array(move_range.stop_cells())
	for cell: Vector2i in candidates:
		var score: float = -100.0 if danger.has(cell) else 0.0
		score -= _nearest_ally_distance_from(state, unit, cell) * 0.5
		if score > best_score:
			best_score = score
			best = cell
	return best


static func _can_attack_this_turn(state: BattleState, unit: UnitState) -> bool:
	if AIRules.is_asleep(unit):
		for slot: int in unit.attack_slot_indices():
			if not CombatContext.attack_targets(state, unit, unit.cell, unit.inventory[slot].weapon()).is_empty():
				return true
		return false
	var reach: Dictionary[Vector2i, bool] = RangeCalculator.attack_cells(state, unit, RangeCalculator.movement(state, unit))
	for other: UnitState in state.all_units():
		if other.is_alive() and not state.are_allied(other.faction_id, unit.faction_id) and reach.has(other.cell):
			return true
	return false


static func _nearest_hostile_distance(state: BattleState, unit: UnitState) -> int:
	return _nearest_hostile_distance_from(state, unit, unit.cell)


static func _nearest_hostile_distance_from(state: BattleState, unit: UnitState, cell: Vector2i) -> int:
	var best: int = 1 << 20
	for other: UnitState in state.all_units():
		if other.is_alive() and not state.are_allied(other.faction_id, unit.faction_id):
			best = mini(best, BattleGrid.distance(cell, other.cell))
	return best


static func _nearest_ally_distance_from(state: BattleState, unit: UnitState, cell: Vector2i) -> int:
	var best: int = 1 << 20
	for other: UnitState in state.all_units():
		if other != unit and other.is_alive() and state.are_allied(other.faction_id, unit.faction_id):
			best = mini(best, BattleGrid.distance(cell, other.cell))
	return best
