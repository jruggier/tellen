class_name ClassChangeRules
extends RefCounted
## Class changes gated by proficiency (spec §6.4–6.5).
##
## A unit may change to a class in its [member UnitData.class_tree] (or any
## class in the ruleset catalog when its tree is empty), other than its
## current class, whose proficiency requirements it meets. Classes tagged
## with [member Ruleset.class_change_excluded_tag] are never offered.
## Level carries over (one continuous level track); stats swap the old
## class's bonuses for the new one's and are clamped to the new caps.


## Classes [param unit] could change into right now.
static func eligible_classes(state: BattleState, unit: UnitState) -> Array[ClassData]:
	var result: Array[ClassData] = []
	var candidates: Array[ClassData] = []
	if unit.unit_data != null and not unit.unit_data.class_tree.is_empty():
		candidates = unit.unit_data.class_tree
	elif unit.unit_data != null:
		candidates = state.ruleset.classes
	for class_data: ClassData in candidates:
		if class_data == null or class_data == unit.class_data or (unit.class_data != null and class_data.id == unit.class_data.id):
			continue
		if class_data.tags.has(state.ruleset.class_change_excluded_tag):
			continue
		if class_data.requirements_met(unit.proficiencies):
			result.append(class_data)
	return result


## Changes [param unit]'s class to [param new_class] and adjusts its stats.
## Returns the stat change (new minus old) for presentation.
static func apply(state: BattleState, unit: UnitState, new_class: ClassData) -> StatBlock:
	var ruleset: Ruleset = state.ruleset
	var old_class: ClassData = unit.class_data
	var before: StatBlock = unit.stats.copy()
	var old_max: int = unit.max_hp(ruleset)
	var stats: StatBlock = unit.stats.copy()
	if old_class != null and old_class.base_stats != null:
		for stat_id: StringName in old_class.base_stats.values:
			stats.set_value(stat_id, stats.get_value(stat_id) - old_class.base_stats.get_value(stat_id))
	if new_class.base_stats != null:
		stats.add_in_place(new_class.base_stats)
	var build_delta: int = new_class.build_bonus - (old_class.build_bonus if old_class != null else 0)
	stats.set_value(ruleset.build_stat, stats.get_value(ruleset.build_stat) + build_delta)
	stats.set_value(ruleset.mov_stat, new_class.mov)
	unit.stats = stats.clamped(new_class.caps)
	unit.class_data = new_class
	var new_max: int = unit.max_hp(ruleset)
	unit.current_hp = clampi(unit.current_hp + (new_max - old_max), 1, new_max)
	var delta := StatBlock.new()
	for stat_id: StringName in unit.stats.values:
		var change: int = unit.stats.get_value(stat_id) - before.get_value(stat_id)
		if change != 0:
			delta.set_value(stat_id, change)
	return delta
