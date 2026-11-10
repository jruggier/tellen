class_name InventorySlot
extends RefCounted
## One inventory entry: an item plus its remaining uses and whether it drops
## when its holder is defeated by the player. Weapons have unlimited uses
## (no durability, spec §9.1).

var item: ItemData
## Remaining uses; -1 = unlimited.
var uses: int = -1
## Given to the unit that defeats the holder.
var drops: bool = false


## A fresh slot for [param data] with full uses.
static func of(data: ItemData, will_drop: bool = false) -> InventorySlot:
	var slot := InventorySlot.new()
	slot.item = data
	slot.uses = (data as ConsumableData).uses if data is ConsumableData else -1
	slot.drops = will_drop
	return slot


func weapon() -> WeaponData:
	return item as WeaponData


func consumable() -> ConsumableData:
	return item as ConsumableData


func copy() -> InventorySlot:
	var other := InventorySlot.new()
	other.item = item
	other.uses = uses
	other.drops = drops
	return other


func to_dict() -> Dictionary:
	return {"item": String(item.id) if item != null else "", "uses": uses, "drops": drops}
