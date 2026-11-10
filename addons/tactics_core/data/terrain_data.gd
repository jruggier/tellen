@tool
class_name TerrainData
extends TacticsData
## One terrain type (plains, forest, fort...). Map tiles reference it through
## the [code]terrain_id[/code] custom data layer of their TileSet.

## Movement cost per movement type id. A movement type missing from this
## dictionary (or with a cost below 1) cannot enter the terrain.
@export var move_costs: Dictionary[StringName, int] = {}

## Avoid bonus for a unit standing here.
@export var avoid_bonus: int = 0

## Bonus added to physical defense for a unit standing here.
@export var defense_bonus: int = 0

## Bonus added to magic defense for a unit standing here.
@export var resistance_bonus: int = 0

## Percent of max HP restored at the start of the occupant's phase.
@export_range(0, 100) var heal_percent: int = 0

## Free-form tags (e.g. "seizable", "water") for rules and AI.
@export var tags: Array[StringName] = []


## True if units of [param movement_type_id] can enter this terrain.
func is_passable_for(movement_type_id: StringName) -> bool:
	return move_costs.get(movement_type_id, 0) >= 1


## Movement cost for [param movement_type_id], or -1 if impassable.
func get_move_cost(movement_type_id: StringName) -> int:
	return move_costs[movement_type_id] if is_passable_for(movement_type_id) else -1


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	for movement_id: StringName in move_costs:
		if move_costs[movement_id] < 1:
			problems.append("%s: move cost for '%s' is %d; remove the entry to make it impassable" % [_label(), movement_id, move_costs[movement_id]])
	return problems
