@tool
class_name CombatRules
extends Resource
## Abstract combat formulas. A game subclasses this and exports its tuning
## numbers; the forecast, resolver and AI only ever call these methods.
##
## Every method takes [CombatParticipant]s and must be pure: no state
## changes, no randomness except through the [SeededRng] passed to the
## [code]roll_*[/code] methods. Displayed percentages are clamped to 0–100.
##
## Methods with a default implementation here are FE-standard behavior that
## most games keep; the rest must be overridden.

## How long Stagger keeps a unit from following up.
enum StaggerDuration {
	## The combat where it was inflicted and the Staggered unit's next combat.
	NEXT_COMBAT,
	## Until the end of the current phase.
	REST_OF_PHASE,
}

## How a displayed hit chance is turned into a roll.
enum TrueHitMode { ONE_RN, TWO_RN, HYBRID }


## Damage one strike from [param attacker] deals to [param defender]
## (before crits and follow-up scaling). Never negative.
func damage(_attacker: CombatParticipant, _defender: CombatParticipant) -> int:
	return _not_implemented("damage")


## Displayed hit chance (0–100).
func displayed_hit(_attacker: CombatParticipant, _defender: CombatParticipant) -> int:
	return _not_implemented("displayed_hit")


## Displayed crit chance (0–100).
func displayed_crit(_attacker: CombatParticipant, _defender: CombatParticipant) -> int:
	return _not_implemented("displayed_crit")


## Damage of a critical strike that would deal [param base_damage].
func crit_damage(_base_damage: int) -> int:
	return _not_implemented("crit_damage")


## Follow-up strength as a percent of damage (0 = no follow-up).
func follow_up_percent(_attacker: CombatParticipant, _defender: CombatParticipant) -> int:
	return _not_implemented("follow_up_percent")


## Damage of a follow-up at [param percent] of [param base_damage].
func follow_up_damage(base_damage: int, percent: int) -> int:
	return floori(base_damage * percent / 100.0)


## True if the defender may follow up at all (subject to follow_up_percent).
func defender_can_follow_up() -> bool:
	return true


## True if [param attacker] effectively deals bonus damage to [param defender].
func is_effective(attacker: CombatParticipant, defender: CombatParticipant) -> bool:
	return attacker.weapon != null and attacker.weapon.is_effective_against(defender.tags)


## Strikes per attack turn (2 for brave weapons).
func strikes_per_turn(participant: CombatParticipant) -> int:
	return 2 if participant.weapon != null and participant.weapon.brave else 1


## True if [param participant] can strike a target at [param distance].
func can_strike_at(participant: CombatParticipant, distance: int) -> bool:
	return participant.has_attack_weapon() and participant.weapon.is_in_range(distance)


## True if [param defender] can counter [param attacker] at [param distance].
func can_counter(defender: CombatParticipant, _attacker: CombatParticipant, distance: int) -> bool:
	return can_strike_at(defender, distance) and not defender.weapon.cannot_counter


## True if a hit from [param attacker] (the initiator) Staggers [param defender]
## (survival is checked by the resolver).
func inflicts_stagger(_attacker: CombatParticipant, _defender: CombatParticipant) -> bool:
	return false


## How long Stagger lasts.
func stagger_duration() -> StaggerDuration:
	return StaggerDuration.NEXT_COMBAT


## HP restored when [param healer] heals with its equipped healing weapon.
func heal_amount(_healer: CombatParticipant) -> int:
	return _not_implemented("heal_amount")


## Rolls a hit at displayed chance [param hit] using the combat stream.
func roll_hit(_rng: SeededRng, _hit: int) -> bool:
	_not_implemented("roll_hit")
	return false


## Rolls a crit at displayed chance [param crit] using the combat stream.
func roll_crit(rng: SeededRng, crit: int) -> bool:
	return rng.roll_100(TacticsIds.STREAM_COMBAT) < crit


## Problems with this rules configuration (empty when valid).
func validate() -> PackedStringArray:
	return PackedStringArray()


func _not_implemented(method_name: String) -> int:
	TacticsLog.error("CombatRules", "%s does not implement %s()" % [resource_path if not resource_path.is_empty() else get_script().resource_path, method_name])
	return 0
