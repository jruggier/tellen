@tool
class_name EnemyStatRules
extends Resource
## Abstract generator for generic enemy stats from class, level and difficulty.
##
## Must be deterministic: the same inputs always give the same stats, so
## maps load identically every time and tests can assert exact values.


## Full stat line for a generic unit of [param class_data] at [param level]
## on difficulty [param difficulty_id].
func generate(_class_data: ClassData, _level: int, _difficulty_id: StringName) -> StatBlock:
	TacticsLog.error("EnemyStatRules", "%s does not implement generate()" % get_script().resource_path)
	return StatBlock.new()


## Problems with this configuration (empty when valid).
func validate() -> PackedStringArray:
	return PackedStringArray()
