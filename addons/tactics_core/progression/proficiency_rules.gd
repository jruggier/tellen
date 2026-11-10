@tool
class_name ProficiencyRules
extends Resource
## Numbered proficiency levels (replacing weapon letter ranks).
##
## Units accumulate points per proficiency id (weapon type id or movement
## type id). [member level_thresholds] gives the total points needed to
## reach each level: index 0 is level 1, index 1 is level 2, and so on.
## Units start at level 0 with 0 points unless their data says otherwise.

## Cumulative points needed for level 1, 2, 3...
@export var level_thresholds: Array[int] = [10, 25, 45, 70, 100]

## Points gained per combat for the class's primary proficiency, by class
## tier (index = tier; the last entry is used for higher tiers).
@export var primary_gain_by_tier: Array[int] = [1, 2]

## Points gained per combat for each secondary proficiency, by class tier.
@export var secondary_gain_by_tier: Array[int] = [1, 1]


## The highest level reachable.
func max_level() -> int:
	return level_thresholds.size()


## Proficiency level for [param points].
func level_for_points(points: int) -> int:
	var level: int = 0
	for threshold: int in level_thresholds:
		if points >= threshold:
			level += 1
		else:
			break
	return level


## Minimum points that give [param level] (0 for level 0).
func points_for_level(level: int) -> int:
	if level <= 0:
		return 0
	return level_thresholds[mini(level, level_thresholds.size()) - 1]


## Points gained per combat for [param proficiency_id] by a unit of
## [param class_data] (0 if the class does not train it).
func gain_for(class_data: ClassData, proficiency_id: StringName) -> int:
	if class_data == null:
		return 0
	if proficiency_id == class_data.primary_proficiency and proficiency_id != &"":
		return _by_tier(primary_gain_by_tier, class_data.tier)
	if class_data.secondary_proficiencies.has(proficiency_id):
		return _by_tier(secondary_gain_by_tier, class_data.tier)
	return 0


## Problems with this configuration (empty when valid).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for i: int in range(1, level_thresholds.size()):
		if level_thresholds[i] <= level_thresholds[i - 1]:
			problems.append("ProficiencyRules: level_thresholds must strictly increase (index %d)" % i)
	if primary_gain_by_tier.is_empty() or secondary_gain_by_tier.is_empty():
		problems.append("ProficiencyRules: gain tables must not be empty")
	return problems


static func _by_tier(table: Array[int], tier: int) -> int:
	if table.is_empty():
		return 0
	return table[clampi(tier, 0, table.size() - 1)]
