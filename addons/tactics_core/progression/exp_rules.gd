@tool
class_name ExpRules
extends Resource
## Abstract experience rules: EXP awarded per action.
##
## Levels are read through [method effective_level] so games with class
## tiers can count promoted units as higher level.


## Outcome of a combat from one unit's point of view.
enum CombatOutcome {
	## No damage dealt.
	MISSED,
	## Dealt damage, target survived.
	DAMAGED,
	## Defeated the target.
	KILLED,
}


## Level used for EXP comparisons.
func effective_level(level: int, _tier: int) -> int:
	return level


## EXP for a combat. Levels/tiers are the unit's and the opponent's.
func combat_exp(_unit_level: int, _unit_tier: int, _enemy_level: int, _enemy_tier: int, _outcome: CombatOutcome, _enemy_is_boss: bool) -> int:
	TacticsLog.error("ExpRules", "%s does not implement combat_exp()" % get_script().resource_path)
	return 0


## EXP for healing an ally.
func heal_exp(_healer_level: int, _healer_tier: int) -> int:
	TacticsLog.error("ExpRules", "%s does not implement heal_exp()" % get_script().resource_path)
	return 0


## Problems with this configuration (empty when valid).
func validate() -> PackedStringArray:
	return PackedStringArray()
