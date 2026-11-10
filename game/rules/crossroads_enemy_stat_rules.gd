@tool
class_name CrossroadsEnemyStatRules
extends EnemyStatRules
## Ruined Crossroads generic enemy stats (spec §6.6).
##
## [codeblock]
## levels = (level − 1) + tier_bonus_levels[tier] + difficulty_bonus_levels[difficulty]
## stat   = min(class generic base + round(class generic growth / 100 × levels), class cap)
## [/codeblock]

## Extra levels of growth per class tier (index = tier; last entry repeats).
@export var tier_bonus_levels: Array[int] = [0, 5, 10, 15]

## Extra levels of growth per difficulty id.
@export var difficulty_bonus_levels: Dictionary[StringName, int] = {&"normal": 0, &"hard": 3, &"maddening": 6}


func generate(class_data: ClassData, level: int, difficulty_id: StringName) -> StatBlock:
	if class_data == null or class_data.generic_base_stats == null:
		TacticsLog.warn("EnemyStatRules", "Class '%s' has no generic_base_stats" % (class_data.id if class_data != null else &"<null>"))
		return StatBlock.new()
	if not difficulty_bonus_levels.has(difficulty_id):
		TacticsLog.warn("EnemyStatRules", "Unknown difficulty '%s'; using 0 bonus levels" % difficulty_id)
	var levels: int = maxi(0, level - 1) + _tier_bonus(class_data.tier) + int(difficulty_bonus_levels.get(difficulty_id, 0))
	var growths: StatBlock = class_data.generic_growths if class_data.generic_growths != null else StatBlock.new()
	var result := StatBlock.new()
	var stat_ids: Array[StringName] = class_data.generic_base_stats.stat_ids()
	for stat_id: StringName in growths.stat_ids():
		if not stat_ids.has(stat_id):
			stat_ids.append(stat_id)
	for stat_id: StringName in stat_ids:
		var value: int = class_data.generic_base_stats.get_value(stat_id) + roundi(growths.get_value(stat_id) / 100.0 * levels)
		if class_data.caps != null and class_data.caps.has_stat(stat_id):
			value = mini(value, class_data.caps.get_value(stat_id))
		result.set_value(stat_id, value)
	return result


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if tier_bonus_levels.is_empty():
		problems.append("CrossroadsEnemyStatRules: tier_bonus_levels is empty")
	return problems


func _tier_bonus(tier: int) -> int:
	if tier_bonus_levels.is_empty():
		return 0
	return tier_bonus_levels[clampi(tier, 0, tier_bonus_levels.size() - 1)]
