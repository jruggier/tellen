@tool
class_name CrossroadsCombatRules
extends CombatRules
## Ruined Crossroads combat formulas (spec §5). All constants are exported.
##
## Summary:
## [br]- Weight penalty = max(0, weapon weight − Build), applied to Speed
##   and Skill (each switchable).
## [br]- Damage = (Str or Mag) + might × effectiveness − (Def or Res + terrain).
## [br]- Hit = weapon hit + 2·Dex + ⌊Skl/2⌋; Avoid = 2·eff.Spd + ⌊Dex/2⌋ + terrain.
## [br]- Crit = weapon crit + ⌊eff.Spd/4⌋; Crit evade = weapon CE + ⌊Skl/4⌋.
## [br]- Follow-up when eff. Skill lead ≥ 5: 50% + 10% per extra point, max 100%.
## [br]- Stagger: the initiator's hit with a weapon type that staggers the
##   defender's (bows and heavy units excluded).

@export_group("Stat ids")
@export var stat_str: StringName = &"str"
@export var stat_mag: StringName = &"mag"
@export var stat_def: StringName = &"def"
@export var stat_res: StringName = &"res"
@export var stat_spd: StringName = &"spd"
@export var stat_skl: StringName = &"skl"
@export var stat_dex: StringName = &"dex"
@export var stat_bld: StringName = &"bld"

@export_group("Weight")
## Weight penalty lowers Speed (avoid and crit).
@export var weight_affects_speed: bool = true
## Weight penalty lowers Skill for the follow-up comparison.
@export var weight_affects_skill_for_followups: bool = true

@export_group("Damage")
## Might multiplier when the weapon is effective against the target.
@export var effective_might_multiplier: int = 3
## Crit damage = ⌊damage × crit_multiplier⌋.
@export var crit_multiplier: float = 3.0

@export_group("Hit and avoid")
@export var hit_per_dex: int = 2
## Hit gains ⌊Skl / hit_skl_divisor⌋.
@export var hit_skl_divisor: int = 2
@export var avoid_per_spd: int = 2
## Avoid gains ⌊Dex / avoid_dex_divisor⌋.
@export var avoid_dex_divisor: int = 2
@export var true_hit_mode: TrueHitMode = TrueHitMode.ONE_RN

@export_group("Crit")
## Crit gains ⌊eff. Spd / crit_spd_divisor⌋.
@export var crit_spd_divisor: int = 4
## Crit evade gains ⌊Skl / crit_evade_skl_divisor⌋.
@export var crit_evade_skl_divisor: int = 4

@export_group("Follow-ups")
## Effective Skill lead needed for a follow-up.
@export var follow_up_threshold: int = 5
## Follow-up percent at exactly the threshold.
@export var follow_up_base_pct: int = 50
## Extra percent per point of lead above the threshold.
@export var follow_up_step_pct: int = 10
@export var follow_up_max_pct: int = 100
@export var allow_defender_follow_up: bool = true

@export_group("Stagger")
@export var stagger_rule_duration: StaggerDuration = StaggerDuration.NEXT_COMBAT


## Weight penalty for [param participant]'s equipped weapon.
func weight_penalty(participant: CombatParticipant) -> int:
	if participant.weapon == null:
		return 0
	return maxi(0, participant.weapon.weight - participant.stat(stat_bld))


## Speed after the weight penalty (used for avoid and crit).
func effective_speed(participant: CombatParticipant) -> int:
	var penalty: int = weight_penalty(participant) if weight_affects_speed else 0
	return participant.stat(stat_spd) - penalty


## Skill after the weight penalty (used only for follow-ups).
func effective_skill_for_follow_ups(participant: CombatParticipant) -> int:
	var penalty: int = weight_penalty(participant) if weight_affects_skill_for_followups else 0
	return participant.stat(stat_skl) - penalty


## Attack value: Str or Mag plus might (×multiplier if effective).
func attack_power(attacker: CombatParticipant, defender: CombatParticipant) -> int:
	if not attacker.has_attack_weapon():
		return 0
	var might: int = attacker.weapon.might + attacker.modifier(CombatParticipant.MOD_MIGHT)
	if is_effective(attacker, defender):
		might *= effective_might_multiplier
	var stat_id: StringName = stat_str if attacker.weapon.damage_type == WeaponData.DamageType.PHYSICAL else stat_mag
	return attacker.stat(stat_id) + might


## The defense value that applies against [param attacker]'s weapon.
func defense_against(defender: CombatParticipant, attacker: CombatParticipant) -> int:
	var physical: bool = attacker.weapon == null or attacker.weapon.damage_type == WeaponData.DamageType.PHYSICAL
	if physical:
		var terrain_def: int = defender.terrain.defense_bonus if defender.terrain != null else 0
		return defender.stat(stat_def) + terrain_def + defender.modifier(CombatParticipant.MOD_DEFENSE)
	var terrain_res: int = defender.terrain.resistance_bonus if defender.terrain != null else 0
	return defender.stat(stat_res) + terrain_res + defender.modifier(CombatParticipant.MOD_RESISTANCE)


func damage(attacker: CombatParticipant, defender: CombatParticipant) -> int:
	if not attacker.has_attack_weapon():
		return 0
	var raw: int = attack_power(attacker, defender) - defense_against(defender, attacker)
	return maxi(0, raw + attacker.modifier(CombatParticipant.MOD_DAMAGE))


## Hit before subtracting the target's avoid.
func hit_total(attacker: CombatParticipant) -> int:
	if not attacker.has_attack_weapon():
		return 0
	return attacker.weapon.hit + hit_per_dex * attacker.stat(stat_dex) \
		+ floori(attacker.stat(stat_skl) / float(hit_skl_divisor)) + attacker.modifier(CombatParticipant.MOD_HIT)


## Avoid including terrain.
func avoid_total(defender: CombatParticipant) -> int:
	var terrain_avoid: int = defender.terrain.avoid_bonus if defender.terrain != null else 0
	return avoid_per_spd * effective_speed(defender) + floori(defender.stat(stat_dex) / float(avoid_dex_divisor)) \
		+ terrain_avoid + defender.modifier(CombatParticipant.MOD_AVOID)


func displayed_hit(attacker: CombatParticipant, defender: CombatParticipant) -> int:
	if not attacker.has_attack_weapon():
		return 0
	return clampi(hit_total(attacker) - avoid_total(defender), 0, 100)


## Crit before subtracting the target's crit evade.
func crit_total(attacker: CombatParticipant) -> int:
	if not attacker.has_attack_weapon():
		return 0
	return attacker.weapon.crit + floori(effective_speed(attacker) / float(crit_spd_divisor)) \
		+ attacker.modifier(CombatParticipant.MOD_CRIT)


## Crit evade from the defender's weapon and Skill.
func crit_evade_total(defender: CombatParticipant) -> int:
	var weapon_ce: int = defender.weapon.crit_evade if defender.weapon != null else 0
	return weapon_ce + floori(defender.stat(stat_skl) / float(crit_evade_skl_divisor)) \
		+ defender.modifier(CombatParticipant.MOD_CRIT_EVADE)


func displayed_crit(attacker: CombatParticipant, defender: CombatParticipant) -> int:
	if not attacker.has_attack_weapon():
		return 0
	return clampi(crit_total(attacker) - crit_evade_total(defender), 0, 100)


func crit_damage(base_damage: int) -> int:
	return floori(base_damage * crit_multiplier)


## Effective Skill lead of [param attacker] over [param defender].
func skill_lead(attacker: CombatParticipant, defender: CombatParticipant) -> int:
	return effective_skill_for_follow_ups(attacker) - effective_skill_for_follow_ups(defender)


func follow_up_percent(attacker: CombatParticipant, defender: CombatParticipant) -> int:
	if attacker.staggered or not attacker.has_attack_weapon():
		return 0
	var lead: int = skill_lead(attacker, defender)
	if lead < follow_up_threshold:
		return 0
	return mini(follow_up_max_pct, follow_up_base_pct + follow_up_step_pct * (lead - follow_up_threshold))


func defender_can_follow_up() -> bool:
	return allow_defender_follow_up


func inflicts_stagger(attacker: CombatParticipant, defender: CombatParticipant) -> bool:
	if not attacker.has_attack_weapon() or defender.weapon == null:
		return false
	if defender.movement_type != null and defender.movement_type.stagger_immune:
		return false
	return attacker.weapon.weapon_type != null and attacker.weapon.weapon_type.staggers_type(defender.weapon.weapon_type)


func stagger_duration() -> StaggerDuration:
	return stagger_rule_duration


func heal_amount(healer: CombatParticipant) -> int:
	if healer.weapon == null or not healer.weapon.heals:
		return 0
	return healer.stat(stat_mag) + healer.weapon.heal_power


func roll_hit(rng: SeededRng, hit: int) -> bool:
	match true_hit_mode:
		TrueHitMode.TWO_RN:
			var first: int = rng.roll_100(TacticsIds.STREAM_COMBAT)
			var second: int = rng.roll_100(TacticsIds.STREAM_COMBAT)
			return (first + second) / 2.0 < hit
		TrueHitMode.HYBRID:
			if hit < 50:
				return rng.roll_100(TacticsIds.STREAM_COMBAT) < hit
			return rng.randi_range(TacticsIds.STREAM_COMBAT, 0, 9999) < hybrid_threshold(hit)
		_:
			return rng.roll_100(TacticsIds.STREAM_COMBAT) < hit


## Fates/Engage curve for displayed hit ≥ 50, on a 0–9999 scale.
static func hybrid_threshold(hit: int) -> float:
	return hit * 100.0 + (40.0 / 3.0) * hit * sin(deg_to_rad((0.02 * hit - 1.0) * 180.0))


## True chance (0–100) that a strike with displayed [param hit] lands, for
## the active hit mode. Used by AI expected-value math.
func true_hit_chance(hit: int) -> float:
	match true_hit_mode:
		TrueHitMode.TWO_RN:
			var successes: int = 0
			for first: int in 100:
				for second: int in 100:
					if (first + second) / 2.0 < hit:
						successes += 1
			return successes / 100.0
		TrueHitMode.HYBRID:
			if hit < 50:
				return float(hit)
			return clampf(ceilf(hybrid_threshold(hit)) / 100.0, 0.0, 100.0)
		_:
			return float(hit)


func debug_details(attacker: CombatParticipant, defender: CombatParticipant) -> Dictionary[String, String]:
	return {
		"Weight penalty": str(weight_penalty(attacker)),
		"Effective Spd": str(effective_speed(attacker)),
		"Effective Skl (follow-ups)": str(effective_skill_for_follow_ups(attacker)),
		"Skill lead": "%+d" % skill_lead(attacker, defender),
		"Hit total": str(hit_total(attacker)),
		"Avoid (own)": str(avoid_total(attacker)),
		"Crit total": str(crit_total(attacker)),
		"Crit evade (own)": str(crit_evade_total(attacker)),
		"Attack": str(attack_power(attacker, defender)),
	}


func forecast_details(attacker: CombatParticipant, defender: CombatParticipant) -> Dictionary[String, String]:
	return {
		"FORECAST_SKILL_LEAD": "%+d" % skill_lead(attacker, defender),
		"FORECAST_WEIGHT_PENALTY": str(-weight_penalty(attacker)) if weight_penalty(attacker) > 0 else "0",
		"FORECAST_ATTACK": str(attack_power(attacker, defender)),
	}


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for value_name: String in ["hit_skl_divisor", "avoid_dex_divisor", "crit_spd_divisor", "crit_evade_skl_divisor"]:
		if int(get(value_name)) <= 0:
			problems.append("CrossroadsCombatRules: %s must be positive" % value_name)
	if follow_up_threshold < 0 or follow_up_max_pct <= 0:
		problems.append("CrossroadsCombatRules: invalid follow-up settings")
	if crit_multiplier < 1.0:
		problems.append("CrossroadsCombatRules: crit_multiplier below 1")
	return problems
