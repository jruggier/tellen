@tool
class_name StatBlock
extends Resource
## A set of stat values keyed by stat id ([member StatDefinition.id]).
##
## Used for base stats, growth rates, caps, bonuses and live unit stats.
## A stat that is not present reads as 0, so blocks only need the stats they
## change. Operations that combine blocks return new blocks and never modify
## their inputs, except the explicit [code]*_in_place[/code] methods.

## Stat id → value.
@export var values: Dictionary[StringName, int] = {}


## Creates a block from a plain dictionary ({"str": 5} or {&"str": 5}).
static func from_values(source: Dictionary) -> StatBlock:
	var block := StatBlock.new()
	for key: Variant in source:
		block.values[StringName(str(key))] = int(source[key])
	return block


## The value of [param stat_id], or 0 if this block does not define it.
func get_value(stat_id: StringName) -> int:
	return values.get(stat_id, 0)


## Sets [param stat_id] to [param value].
func set_value(stat_id: StringName, value: int) -> void:
	values[stat_id] = value


## True if this block defines [param stat_id] (even as 0).
func has_stat(stat_id: StringName) -> bool:
	return values.has(stat_id)


## Stat ids defined in this block, sorted for deterministic iteration.
func stat_ids() -> Array[StringName]:
	var ids: Array[StringName] = values.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## Returns a new block with every stat of this block and [param other] summed.
func plus(other: StatBlock) -> StatBlock:
	var result: StatBlock = copy()
	result.add_in_place(other)
	return result


## Adds [param other]'s values into this block.
func add_in_place(other: StatBlock) -> void:
	if other == null:
		return
	for stat_id: StringName in other.values:
		values[stat_id] = get_value(stat_id) + other.values[stat_id]


## Returns a new block clamped so no stat exceeds its value in [param caps]
## (stats missing from [param caps] are left alone) and none falls below
## [param floor_value].
func clamped(caps: StatBlock, floor_value: int = 0) -> StatBlock:
	var result := StatBlock.new()
	for stat_id: StringName in values:
		var value: int = maxi(values[stat_id], floor_value)
		if caps != null and caps.has_stat(stat_id):
			value = mini(value, caps.get_value(stat_id))
		result.values[stat_id] = value
	return result


## An independent copy.
func copy() -> StatBlock:
	var result := StatBlock.new()
	result.values = values.duplicate()
	return result


## True if both blocks hold the same values, treating missing stats as 0.
func equals(other: StatBlock) -> bool:
	if other == null:
		return false
	for stat_id: StringName in values:
		if get_value(stat_id) != other.get_value(stat_id):
			return false
	for stat_id: StringName in other.values:
		if get_value(stat_id) != other.get_value(stat_id):
			return false
	return true


## JSON-safe dictionary (string keys).
func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for stat_id: StringName in stat_ids():
		result[String(stat_id)] = values[stat_id]
	return result


## Readable form for logs and test failures, e.g. "{hp: 20, str: 6}".
func _to_string() -> String:
	var parts: PackedStringArray = []
	for stat_id: StringName in stat_ids():
		parts.append("%s: %d" % [stat_id, values[stat_id]])
	return "{%s}" % ", ".join(parts)
