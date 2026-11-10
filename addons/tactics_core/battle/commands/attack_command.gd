class_name AttackCommand
extends Command
## Attacks a hostile unit with the weapon in a chosen inventory slot (which
## becomes the equipped weapon), resolves the combat and applies the result:
## HP, Stagger, defeats and drops, EXP, level-ups and proficiency.
##
## Results are kept on the command ([member result], [member reports],
## [member defeats]) so presentation can replay them after the state has
## already changed.

## Stagger counter value meaning "until the end of this phase".
const STAGGER_REST_OF_PHASE: int = 1 << 20

var attacker_id: StringName
var defender_id: StringName
var slot_index: int
var result: CombatResult
## Unit id → what it gained.
var reports: Dictionary[StringName, ProgressionService.Report] = {}
var defeats: Array[DefeatRules.Outcome] = []
## Visible skill effects after combat ({"unit", "heal", "text"}).
var skill_effects: Array[Dictionary] = []


func _init(attacking_unit: StringName = &"", target_unit: StringName = &"", weapon_slot: int = 0) -> void:
	attacker_id = attacking_unit
	defender_id = target_unit
	slot_index = weapon_slot


func get_type() -> StringName:
	return &"attack"


func can_execute(state: BattleState) -> bool:
	var attacker: UnitState = state.get_unit(attacker_id)
	var defender: UnitState = state.get_unit(defender_id)
	if attacker == null or defender == null or not attacker.is_ready() or not defender.is_alive():
		return false
	if state.current_faction() != null and state.current_faction().id != attacker.faction_id:
		return false
	if state.are_allied(attacker.faction_id, defender.faction_id):
		return false
	if not attacker.attack_slot_indices().has(slot_index):
		return false
	return attacker.inventory[slot_index].weapon().is_in_range(BattleGrid.distance(attacker.cell, defender.cell))


func execute(state: BattleState) -> void:
	var attacker: UnitState = state.get_unit(attacker_id)
	var defender: UnitState = state.get_unit(defender_id)
	var rules: CombatRules = state.ruleset.combat_rules
	attacker.equip_slot(slot_index)
	var weapon: WeaponData = attacker.equipped_weapon()
	var a: CombatParticipant = CombatContext.participant(state, attacker, attacker.cell, weapon, defender, true)
	var d: CombatParticipant = CombatContext.participant(state, defender, defender.cell, defender.equipped_weapon(), attacker, false)
	result = CombatResolver.resolve(rules, a, d, BattleGrid.distance(attacker.cell, defender.cell), state.rng)

	# Carried Stagger is used up by this combat (NEXT_COMBAT rule).
	if rules.stagger_duration() == CombatRules.StaggerDuration.NEXT_COMBAT:
		for unit: UnitState in [attacker, defender]:
			unit.stagger_combats = maxi(0, unit.stagger_combats - 1)
	if result.defender_staggered:
		defender.stagger_combats = 1 if rules.stagger_duration() == CombatRules.StaggerDuration.NEXT_COMBAT else STAGGER_REST_OF_PHASE

	attacker.current_hp = result.attacker_hp_after
	defender.current_hp = result.defender_hp_after
	if AIRules.is_asleep(defender):
		AIRules.wake(state, defender)
	if result.defender_defeated():
		defeats.append(DefeatRules.apply(state, defender, attacker))
	if result.attacker_defeated():
		defeats.append(DefeatRules.apply(state, attacker, defender))

	skill_effects.append_array(SkillRunner.combat_end(state, attacker, defender, result, Strike.Role.ATTACKER))
	skill_effects.append_array(SkillRunner.combat_end(state, defender, attacker, result, Strike.Role.DEFENDER))
	_progress(state, attacker, defender, Strike.Role.ATTACKER, weapon)
	_progress(state, defender, attacker, Strike.Role.DEFENDER, d.weapon)
	attacker.has_moved = true
	attacker.has_acted = true
	state.mark_changed()


## EXP and proficiency for [param unit] (if its faction earns them).
func _progress(state: BattleState, unit: UnitState, opponent: UnitState, role: Strike.Role, weapon: WeaponData) -> void:
	if not ProgressionService.gains_experience(state, unit):
		return
	var struck: bool = not result.strikes_by(role).is_empty()
	var dealt: bool = result.attacker_dealt_damage if role == Strike.Role.ATTACKER else result.defender_dealt_damage
	var outcome: ExpRules.CombatOutcome = ExpRules.CombatOutcome.MISSED
	if not opponent.is_alive():
		outcome = ExpRules.CombatOutcome.KILLED
	elif dealt:
		outcome = ExpRules.CombatOutcome.DAMAGED
	var tier: int = unit.class_data.tier if unit.class_data != null else 0
	var opponent_tier: int = opponent.class_data.tier if opponent.class_data != null else 0
	var report := ProgressionService.Report.new()
	var amount: int = state.ruleset.exp_rules.combat_exp(unit.level, tier, opponent.level, opponent_tier, outcome, opponent.is_boss)
	ProgressionService.award_exp(state, unit, amount, report)
	if struck and weapon != null and weapon.weapon_type != null:
		ProgressionService.train_proficiency(state, unit, weapon.weapon_type.id, report)
	reports[unit.id] = report


func emit_events(events: Node) -> void:
	events.emit_signal(&"combat_resolved", attacker_id, defender_id, result)
	for outcome: DefeatRules.Outcome in defeats:
		events.emit_signal(&"unit_defeated", outcome.unit_id, outcome.by_unit_id)
	for unit_id: StringName in reports:
		var report: ProgressionService.Report = reports[unit_id]
		for i: int in report.level_gains.size():
			events.emit_signal(&"level_up", unit_id, report.old_level + i + 1, report.level_gains[i])


func to_dict() -> Dictionary:
	return {"type": "attack", "attacker": String(attacker_id), "defender": String(defender_id), "slot": slot_index,
		"result": result.to_dict() if result != null else {}}
