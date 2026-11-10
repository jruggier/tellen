@tool
class_name ConsumableData
extends ItemData
## A usable item with limited uses: healing items and permanent stat boosters.

## Uses before the item is consumed.
@export_range(1, 99) var uses: int = 1

## HP restored per use (ignored when [member heal_full] is set).
@export var heal_amount: int = 0

## Restores HP to full.
@export var heal_full: bool = false

## Permanent stat increases applied on use (e.g. +2 Str).
@export var permanent_boosts: StatBlock


## True if using this item restores HP.
func heals() -> bool:
	return heal_full or heal_amount > 0


func validate() -> PackedStringArray:
	var problems: PackedStringArray = super()
	var boosts: bool = permanent_boosts != null and not permanent_boosts.values.is_empty()
	if not heals() and not boosts:
		problems.append("%s: has no effect (no healing and no permanent boosts)" % _label())
	return problems
