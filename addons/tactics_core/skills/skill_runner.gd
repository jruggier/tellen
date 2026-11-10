class_name SkillRunner
extends RefCounted
## Finds a unit's active skills and runs their hooks.
##
## Active skills = class abilities (always on, no slot) + equipped skills
## (up to the ruleset's skill slots) + skills granted while awakened.

## Auras reach at most this far; each skill decides its own radius within it.
const MAX_AURA_RADIUS: int = 3

static var _hooks_cache: Dictionary[String, SkillHooks] = {}


## Every skill currently active on [param unit].
static func active_skills(unit: UnitState) -> Array[SkillData]:
	var result: Array[SkillData] = []
	if unit.class_data != null:
		result.append_array(unit.class_data.abilities)
	result.append_array(unit.skills)
	if unit.awakened and unit.awakening != null:
		result.append_array(unit.awakening.skills)
	return result


## True if [param unit] has a skill with [param skill_id] active.
static func has_skill(unit: UnitState, skill_id: StringName) -> bool:
	for skill: SkillData in active_skills(unit):
		if skill.id == skill_id:
			return true
	return false


## The shared hooks instance for [param skill], or null if it has no script.
static func hooks_for(skill: SkillData) -> SkillHooks:
	if skill == null or skill.hooks_script == null:
		return null
	var key: String = skill.hooks_script.resource_path
	if not _hooks_cache.has(key):
		var instance: Variant = skill.hooks_script.new()
		if not (instance is SkillHooks):
			TacticsLog.warn("SkillRunner", "Skill '%s': hooks_script does not extend SkillHooks" % skill.id)
			return null
		_hooks_cache[key] = instance
	return _hooks_cache[key]


## Applies [param unit]'s own skills and nearby allies' auras to
## [param participant], with the unit standing on [param at_cell] (which may
## be a hypothetical destination for forecasts and AI).
static func apply_to_participant(state: BattleState, unit: UnitState, at_cell: Vector2i, participant: CombatParticipant,
		opponent: UnitState, is_initiator: bool) -> void:
	for skill: SkillData in active_skills(unit):
		var hooks: SkillHooks = hooks_for(skill)
		if hooks != null:
			var own: SkillContext = _context(state, skill, unit, participant, unit, opponent, is_initiator, 0)
			own.cell = at_cell
			hooks.modify_participant(own)
	for ally: UnitState in state.all_units():
		if ally == unit or not ally.is_alive() or ally.faction_id != unit.faction_id:
			continue
		var distance: int = BattleGrid.distance(ally.cell, at_cell)
		if distance > MAX_AURA_RADIUS or distance == 0:
			continue
		for skill: SkillData in active_skills(ally):
			var hooks: SkillHooks = hooks_for(skill)
			if hooks != null:
				var aura: SkillContext = _context(state, skill, ally, participant, unit, opponent, is_initiator, distance)
				aura.cell = at_cell
				hooks.modify_ally_participant(aura)


## Runs [method SkillHooks.on_combat_end] for [param unit]; returns effects.
static func combat_end(state: BattleState, unit: UnitState, opponent: UnitState, result: CombatResult, role: Strike.Role) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if not unit.is_alive():
		return effects
	for skill: SkillData in active_skills(unit):
		var hooks: SkillHooks = hooks_for(skill)
		if hooks == null:
			continue
		var ctx: SkillContext = _context(state, skill, unit, null, unit, opponent, role == Strike.Role.ATTACKER, 0)
		ctx.result = result
		ctx.role = role
		hooks.on_combat_end(ctx)
		effects.append_array(ctx.effects)
	return effects


## Runs [method SkillHooks.on_phase_start] for every unit of [param faction_id].
static func phase_start(state: BattleState, faction_id: StringName) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for unit: UnitState in state.units_of(faction_id):
		for skill: SkillData in active_skills(unit):
			var hooks: SkillHooks = hooks_for(skill)
			if hooks != null:
				var ctx: SkillContext = _context(state, skill, unit, null, unit, null, false, 0)
				hooks.on_phase_start(ctx)
				effects.append_array(ctx.effects)
	return effects


## True if [param unit] may move again after acting.
static func has_canto(state: BattleState, unit: UnitState) -> bool:
	for skill: SkillData in active_skills(unit):
		var hooks: SkillHooks = hooks_for(skill)
		if hooks != null and hooks.grants_canto(_context(state, skill, unit, null, unit, null, false, 0)):
			return true
	return false


static func _context(state: BattleState, skill: SkillData, owner: UnitState, subject: CombatParticipant, subject_unit: UnitState,
		opponent: UnitState, is_initiator: bool, distance: int) -> SkillContext:
	var ctx := SkillContext.new()
	ctx.state = state
	ctx.skill = skill
	ctx.owner = owner
	ctx.subject = subject
	ctx.subject_unit = subject_unit
	ctx.opponent = opponent
	ctx.is_initiator = is_initiator
	ctx.distance = distance
	return ctx
