class_name ProgressionService
extends RefCounted
## Applies EXP, level-ups and proficiency gains to units (spec §6).
## Called by commands after combat or healing; uses the ruleset's rules and
## the battle's growth RNG stream, so results are deterministic.


## What one unit gained from an action, for presentation.
class Report:
	extends RefCounted
	var unit_id: StringName
	var exp_gained: int = 0
	var old_level: int = 0
	var new_level: int = 0
	## Stat gains, one block per level gained.
	var level_gains: Array[StatBlock] = []
	## Proficiency ids whose level rose → new level.
	var proficiency_ups: Dictionary[StringName, int] = {}

	func leveled_up() -> bool:
		return new_level > old_level


## True if [param unit]'s faction earns EXP.
static func gains_experience(state: BattleState, unit: UnitState) -> bool:
	var faction: FactionData = state.get_faction(unit.faction_id)
	return faction != null and faction.gains_experience and unit.is_alive()


## Adds [param amount] EXP to [param unit] (levelling up as needed) and
## fills [param report]. Units at the level cap gain nothing.
static func award_exp(state: BattleState, unit: UnitState, amount: int, report: Report) -> void:
	var ruleset: Ruleset = state.ruleset
	report.unit_id = unit.id
	report.old_level = unit.level
	report.new_level = unit.level
	if unit.level >= ruleset.level_cap or amount <= 0:
		return
	report.exp_gained = amount
	unit.experience += amount
	while unit.experience >= ruleset.exp_per_level and unit.level < ruleset.level_cap:
		unit.experience -= ruleset.exp_per_level
		report.level_gains.append(level_up(state, unit))
	if unit.level >= ruleset.level_cap:
		unit.experience = 0
	report.new_level = unit.level


## Raises [param unit] one level: rolls growths, clamps to class caps,
## raises current HP by the HP gained. Returns the actual gains.
static func level_up(state: BattleState, unit: UnitState) -> StatBlock:
	var ruleset: Ruleset = state.ruleset
	var rolled: StatBlock = ruleset.growth_rules.roll_level_up(unit.growths(ruleset), ruleset.growable_stat_ids(), state.rng, unit.growth_counters)
	var before: StatBlock = unit.stats.copy()
	var caps: StatBlock = unit.class_data.caps if unit.class_data != null else null
	var raised: StatBlock = unit.stats.plus(rolled).clamped(caps)
	var gains := StatBlock.new()
	for stat_id: StringName in rolled.values:
		var delta: int = raised.get_value(stat_id) - before.get_value(stat_id)
		if delta > 0:
			gains.set_value(stat_id, delta)
	unit.stats = raised
	unit.level += 1
	unit.current_hp = mini(unit.current_hp + gains.get_value(ruleset.hp_stat), unit.max_hp(ruleset))
	return gains


## Grants proficiency points after [param unit] used a weapon of
## [param weapon_type_id]: that weapon type and the class's movement tactic,
## each only if the class trains it (§6.4). Fills [param report].
static func train_proficiency(state: BattleState, unit: UnitState, weapon_type_id: StringName, report: Report) -> void:
	var rules: ProficiencyRules = state.ruleset.proficiency_rules
	if rules == null or unit.class_data == null:
		return
	var trained: Array[StringName] = [weapon_type_id]
	var tactic: StringName = unit.movement_type_id()
	if tactic != &"" and not trained.has(tactic):
		trained.append(tactic)
	for proficiency_id: StringName in trained:
		var gain: int = rules.gain_for(unit.class_data, proficiency_id)
		if gain <= 0:
			continue
		var points: int = int(unit.proficiency_points.get(proficiency_id, 0)) + gain
		unit.proficiency_points[proficiency_id] = points
		var old_level: int = int(unit.proficiencies.get(proficiency_id, 0))
		var new_level: int = maxi(old_level, rules.level_for_points(points))
		if new_level > old_level:
			unit.proficiencies[proficiency_id] = new_level
			report.proficiency_ups[proficiency_id] = new_level
