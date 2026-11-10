@tool
class_name UnitPlacement
extends Resource
## One unit to place when a battle starts: a named unit, or a generic unit
## of a class at a level, on a cell, for a faction.
##
## Map markers (M7) produce these; until then maps list them directly.

## Named unit. Leave empty for a generic unit.
@export var unit_data: UnitData
## Class of a generic unit (ignored when [member unit_data] is set).
@export var class_data: ClassData
## Level of a generic unit.
@export_range(1, 99) var level: int = 1
@export var faction_id: StringName = &"enemy"
@export var cell: Vector2i = Vector2i.ZERO
## Inventory for generic units (named units use their own).
@export var items: Array[ItemData] = []
@export var is_boss: bool = false
## Battle id; generated from the unit or class id when empty.
@export var unit_id: StringName = &""


## Problems with this placement (empty when valid).
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if unit_data == null and class_data == null:
		problems.append("UnitPlacement at %s: needs unit_data or class_data" % cell)
	if faction_id == &"":
		problems.append("UnitPlacement at %s: no faction_id" % cell)
	return problems
