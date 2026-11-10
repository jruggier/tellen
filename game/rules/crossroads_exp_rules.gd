@tool
class_name CrossroadsExpRules
extends ExpRules
## Ruined Crossroads EXP (spec §6.3), FE-like.
##
## [codeblock]
## level_diff = enemy effective level − unit effective level
## combat     = max(1, combat_base + level_diff)
## kill       = combat + max(0, kill_base + level_diff × kill_level_mult) + boss bonus
## miss       = miss_exp
## heal       = heal_exp_amount
## [/codeblock]
## Every result is clamped to [member min_exp]–[member max_exp].

## Levels added per class tier when comparing levels (0 = levels compare directly).
@export var tier_level_offset: int = 0
@export var combat_base: int = 10
@export var kill_base: int = 20
@export var kill_level_mult: int = 3
@export var boss_kill_bonus: int = 40
@export var miss_exp: int = 1
@export var heal_exp_amount: int = 12
@export var min_exp: int = 1
@export var max_exp: int = 100


func effective_level(level: int, tier: int) -> int:
	return level + tier * tier_level_offset


func combat_exp(unit_level: int, unit_tier: int, enemy_level: int, enemy_tier: int, outcome: CombatOutcome, enemy_is_boss: bool) -> int:
	if outcome == CombatOutcome.MISSED:
		return _clamp(miss_exp)
	var level_diff: int = effective_level(enemy_level, enemy_tier) - effective_level(unit_level, unit_tier)
	var amount: int = maxi(1, combat_base + level_diff)
	if outcome == CombatOutcome.KILLED:
		amount += maxi(0, kill_base + level_diff * kill_level_mult)
		if enemy_is_boss:
			amount += boss_kill_bonus
	return _clamp(amount)


func heal_exp(_healer_level: int, _healer_tier: int) -> int:
	return _clamp(heal_exp_amount)


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if min_exp > max_exp:
		problems.append("CrossroadsExpRules: min_exp > max_exp")
	return problems


func _clamp(value: int) -> int:
	return clampi(value, min_exp, max_exp)
