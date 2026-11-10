class_name UnitStats
extends RefCounted
## Stat calculations for units outside of battle: starting stats, average
## stats at a level, generic units. Used by unit creation, the Combat Lab
## and tuning tools.
##
## Total stats = personal base + class base stats (+ class Build bonus),
## clamped to class caps. Movement comes from the class.


## Stats of [param unit] at its authored level.
static func starting_stats(unit: UnitData, ruleset: Ruleset) -> StatBlock:
	return average_at_level(unit, ruleset, unit.level)


## Expected stats of [param unit] at [param level]: each growable stat gains
## round(growth × levels gained / 100), as if growths landed on average.
static func average_at_level(unit: UnitData, ruleset: Ruleset, level: int) -> StatBlock:
	var class_data: ClassData = unit.class_data
	var stats: StatBlock = unit.personal_base.copy() if unit.personal_base != null else StatBlock.new()
	if class_data != null and class_data.base_stats != null:
		stats.add_in_place(class_data.base_stats)
	var levels_gained: int = maxi(0, level - unit.level)
	if levels_gained > 0:
		var growths: StatBlock = ruleset.growth_rules.effective_growths(unit.personal_growths, class_data)
		for stat_id: StringName in ruleset.growable_stat_ids():
			var gain: int = roundi(growths.get_value(stat_id) * levels_gained / 100.0)
			stats.set_value(stat_id, stats.get_value(stat_id) + gain)
	return _finish(stats, class_data, ruleset, true)


## Stats of a generic unit of [param class_data] at [param level].
static func generic(class_data: ClassData, ruleset: Ruleset, level: int, difficulty_id: StringName = &"normal") -> StatBlock:
	var stats: StatBlock = ruleset.enemy_stat_rules.generate(class_data, level, difficulty_id)
	return _finish(stats, class_data, ruleset, false)


## Unit tags for effectiveness and rules: movement type id, movement type
## tags, class tags and the unit's own tags.
static func tags_for(class_data: ClassData, extra_tags: Array[StringName] = []) -> Array[StringName]:
	var tags: Array[StringName] = []
	if class_data != null:
		if class_data.movement_type != null:
			tags.append(class_data.movement_type.id)
			tags.append_array(class_data.movement_type.tags)
		tags.append_array(class_data.tags)
	tags.append_array(extra_tags)
	var unique: Array[StringName] = []
	for tag: StringName in tags:
		if not unique.has(tag):
			unique.append(tag)
	return unique


static func _finish(stats: StatBlock, class_data: ClassData, ruleset: Ruleset, add_build_bonus: bool) -> StatBlock:
	if class_data == null:
		return stats
	if add_build_bonus:
		stats.set_value(ruleset.build_stat, stats.get_value(ruleset.build_stat) + class_data.build_bonus)
	stats.set_value(ruleset.mov_stat, class_data.mov)
	return stats.clamped(class_data.caps)
