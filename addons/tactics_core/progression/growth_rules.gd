@tool
class_name GrowthRules
extends Resource
## Abstract level-up rules: which stats rise on a level-up.
##
## [method roll_level_up] returns the gains only; the caller adds them and
## clamps to class caps. [param counters] is per-unit hidden state (stat id →
## accumulated percent) that deterministic modes use; it must be saved with
## the unit and is modified in place.


## Final growth rates for a unit: personal growths plus class modifiers.
func effective_growths(personal_growths: StatBlock, class_data: ClassData) -> StatBlock:
	var result: StatBlock = personal_growths.copy() if personal_growths != null else StatBlock.new()
	if class_data != null and class_data.growth_modifiers != null:
		result.add_in_place(class_data.growth_modifiers)
	return result


## Stat gains for one level-up. [param growable_stats] lists the stat ids
## that may grow; [param growths] holds percent rates.
func roll_level_up(_growths: StatBlock, _growable_stats: Array[StringName], _rng: SeededRng, _counters: Dictionary) -> StatBlock:
	TacticsLog.error("GrowthRules", "%s does not implement roll_level_up()" % get_script().resource_path)
	return StatBlock.new()


## Problems with this configuration (empty when valid).
func validate() -> PackedStringArray:
	return PackedStringArray()
