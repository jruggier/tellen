@tool
class_name ItemData
extends TacticsData
## Base class for anything that fits in an inventory slot.
##
## See [WeaponData] and [ConsumableData]. Extension point: shops (out of
## scope for now) read [member value].

## Inventory/menu icon.
@export var icon: Texture2D

## Trade value, for future shops and loot tables.
@export var value: int = 0

## Free-form tags for rules, AI and events (e.g. "key", "booster").
@export var tags: Array[StringName] = []
