class_name CombatContext
extends RefCounted
## Bridges battle state and the pure combat code: builds
## [CombatParticipant]s from [UnitState]s (stats, weapon, the terrain they
## stand on, tags, carried Stagger) and finds valid targets.


## A participant for [param unit] standing on [param cell] with [param weapon],
## with its skills and nearby allies' auras applied. [param opponent] and
## [param is_initiator] let skills react to the matchup.
static func participant(state: BattleState, unit: UnitState, cell: Vector2i, weapon: WeaponData,
		opponent: UnitState = null, is_initiator: bool = true) -> CombatParticipant:
	var p := CombatParticipant.new()
	p.unit_id = unit.id
	p.stats = unit.effective_stats().copy()
	p.weapon = weapon
	p.terrain = state.grid.terrain_at(cell)
	p.movement_type = unit.class_data.movement_type if unit.class_data != null else null
	p.tags = unit.get_tags()
	p.current_hp = unit.current_hp
	p.level = unit.level
	p.tier = unit.class_data.tier if unit.class_data != null else 0
	p.staggered = unit.is_staggered()
	p.is_boss = unit.is_boss
	if opponent != null:
		SkillRunner.apply_to_participant(state, unit, cell, p, opponent, is_initiator)
	return p


## Forecast for [param attacker] attacking [param defender] from
## [param from_cell] with [param weapon] (the defender uses its equipped weapon).
static func forecast(state: BattleState, attacker: UnitState, defender: UnitState, from_cell: Vector2i, weapon: WeaponData) -> CombatForecast:
	var a: CombatParticipant = participant(state, attacker, from_cell, weapon, defender, true)
	var d: CombatParticipant = participant(state, defender, defender.cell, defender.equipped_weapon(), attacker, false)
	return CombatForecast.calculate(state.ruleset.combat_rules, a, d, BattleGrid.distance(from_cell, defender.cell))


## Living hostile units [param unit] could hit from [param cell] with [param weapon].
static func attack_targets(state: BattleState, unit: UnitState, cell: Vector2i, weapon: WeaponData) -> Array[UnitState]:
	var result: Array[UnitState] = []
	if weapon == null or weapon.heals:
		return result
	for other: UnitState in state.all_units():
		if other.is_alive() and not state.are_allied(other.faction_id, unit.faction_id) \
				and weapon.is_in_range(BattleGrid.distance(cell, other.cell)):
			result.append(other)
	return result


## Injured allies [param unit] could heal from [param cell] with [param staff].
static func heal_targets(state: BattleState, unit: UnitState, cell: Vector2i, staff: WeaponData) -> Array[UnitState]:
	var result: Array[UnitState] = []
	if staff == null or not staff.heals:
		return result
	for other: UnitState in state.all_units():
		if other != unit and other.is_alive() and state.are_allied(other.faction_id, unit.faction_id) \
				and other.current_hp < other.max_hp(state.ruleset) and staff.is_in_range(BattleGrid.distance(cell, other.cell)):
			result.append(other)
	return result


## Same-faction units orthogonally adjacent to [param cell] (trade partners).
static func adjacent_allies(state: BattleState, unit: UnitState, cell: Vector2i) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for neighbor: Vector2i in state.grid.neighbors(cell):
		var other: UnitState = state.unit_at(neighbor)
		if other != null and other != unit and other.faction_id == unit.faction_id:
			result.append(other)
	return result
