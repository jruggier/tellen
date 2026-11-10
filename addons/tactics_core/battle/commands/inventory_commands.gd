class_name InventoryCommands
extends RefCounted
## Inventory commands (spec §9.1): use a consumable (ends the action),
## equip, discard and trade (free actions taken before acting).
##
## Free actions cannot be undone and lock in the unit's move, like trading
## in FE. Each command is an inner class: [code]InventoryCommands.Use[/code], etc.


static func _can_act(state: BattleState, unit: UnitState) -> bool:
	if unit == null or not unit.is_ready():
		return false
	return state.current_faction() == null or state.current_faction().id == unit.faction_id


## Uses a consumable: heals or permanently raises stats (clamped to class
## caps). One use is spent; the slot empties at 0. Ends the action.
class Use:
	extends Command
	var unit_id: StringName
	var slot_index: int
	var healed: int = 0
	var boosts := StatBlock.new()

	func _init(using_unit: StringName = &"", slot: int = 0) -> void:
		unit_id = using_unit
		slot_index = slot

	func get_type() -> StringName:
		return &"use_item"

	func can_execute(state: BattleState) -> bool:
		var unit: UnitState = state.get_unit(unit_id)
		if not InventoryCommands._can_act(state, unit) or slot_index < 0 or slot_index >= unit.inventory.size():
			return false
		var item: ConsumableData = unit.inventory[slot_index].consumable()
		if item == null:
			return false
		var has_boosts: bool = item.permanent_boosts != null and not item.permanent_boosts.values.is_empty()
		return has_boosts or (item.heals() and unit.current_hp < unit.max_hp(state.ruleset))

	func execute(state: BattleState) -> void:
		var unit: UnitState = state.get_unit(unit_id)
		var slot: InventorySlot = unit.inventory[slot_index]
		var item: ConsumableData = slot.consumable()
		var ruleset: Ruleset = state.ruleset
		if item.permanent_boosts != null and not item.permanent_boosts.values.is_empty():
			var caps: StatBlock = unit.class_data.caps if unit.class_data != null else null
			var raised: StatBlock = unit.stats.plus(item.permanent_boosts).clamped(caps)
			for stat_id: StringName in item.permanent_boosts.values:
				var delta: int = raised.get_value(stat_id) - unit.stats.get_value(stat_id)
				if delta > 0:
					boosts.set_value(stat_id, delta)
			unit.stats = raised
			unit.current_hp += boosts.get_value(ruleset.hp_stat)
		if item.heals():
			var before: int = unit.current_hp
			var target_hp: int = unit.max_hp(ruleset) if item.heal_full else unit.current_hp + item.heal_amount
			unit.current_hp = mini(unit.max_hp(ruleset), target_hp)
			healed = unit.current_hp - before
		slot.uses -= 1
		if slot.uses <= 0:
			unit.inventory.remove_at(slot_index)
		unit.has_moved = true
		unit.has_acted = true
		state.mark_changed()

	func emit_events(events: Node) -> void:
		if healed > 0:
			events.emit_signal(&"unit_healed", unit_id, healed)

	func to_dict() -> Dictionary:
		return {"type": "use_item", "unit": String(unit_id), "slot": slot_index}


## Moves a weapon to the top of the inventory, making it the equipped one.
class Equip:
	extends Command
	var unit_id: StringName
	var slot_index: int

	func _init(equipping_unit: StringName = &"", slot: int = 0) -> void:
		unit_id = equipping_unit
		slot_index = slot

	func get_type() -> StringName:
		return &"equip"

	func can_execute(state: BattleState) -> bool:
		var unit: UnitState = state.get_unit(unit_id)
		if not InventoryCommands._can_act(state, unit) or slot_index < 0 or slot_index >= unit.inventory.size():
			return false
		return unit.can_equip(unit.inventory[slot_index].weapon())

	func execute(state: BattleState) -> void:
		state.get_unit(unit_id).equip_slot(slot_index)
		state.mark_changed()

	func to_dict() -> Dictionary:
		return {"type": "equip", "unit": String(unit_id), "slot": slot_index}


## Throws an item away.
class Discard:
	extends Command
	var unit_id: StringName
	var slot_index: int

	func _init(discarding_unit: StringName = &"", slot: int = 0) -> void:
		unit_id = discarding_unit
		slot_index = slot

	func get_type() -> StringName:
		return &"discard"

	func can_execute(state: BattleState) -> bool:
		var unit: UnitState = state.get_unit(unit_id)
		return InventoryCommands._can_act(state, unit) and slot_index >= 0 and slot_index < unit.inventory.size()

	func execute(state: BattleState) -> void:
		state.get_unit(unit_id).inventory.remove_at(slot_index)
		state.mark_changed()

	func to_dict() -> Dictionary:
		return {"type": "discard", "unit": String(unit_id), "slot": slot_index}


## Swaps two slots between adjacent same-faction units, or moves an item
## into the other unit's free space (slot index = its inventory size).
class Trade:
	extends Command
	var unit_id: StringName
	var unit_slot: int
	var partner_id: StringName
	var partner_slot: int

	func _init(trading_unit: StringName = &"", own_slot: int = 0, partner: StringName = &"", their_slot: int = 0) -> void:
		unit_id = trading_unit
		unit_slot = own_slot
		partner_id = partner
		partner_slot = their_slot

	func get_type() -> StringName:
		return &"trade"

	func can_execute(state: BattleState) -> bool:
		var unit: UnitState = state.get_unit(unit_id)
		var partner: UnitState = state.get_unit(partner_id)
		if not InventoryCommands._can_act(state, unit) or partner == null or not CombatContext.adjacent_allies(state, unit, unit.cell).has(partner):
			return false
		var own_has: bool = unit_slot >= 0 and unit_slot < unit.inventory.size()
		var their_has: bool = partner_slot >= 0 and partner_slot < partner.inventory.size()
		if not own_has and not their_has:
			return false
		if not own_has and (unit_slot != unit.inventory.size() or not unit.has_inventory_space(state.ruleset)):
			return false
		if not their_has and (partner_slot != partner.inventory.size() or not partner.has_inventory_space(state.ruleset)):
			return false
		return true

	func execute(state: BattleState) -> void:
		var unit: UnitState = state.get_unit(unit_id)
		var partner: UnitState = state.get_unit(partner_id)
		var own: InventorySlot = unit.inventory[unit_slot] if unit_slot < unit.inventory.size() else null
		var theirs: InventorySlot = partner.inventory[partner_slot] if partner_slot < partner.inventory.size() else null
		if own != null and theirs != null:
			unit.inventory[unit_slot] = theirs
			partner.inventory[partner_slot] = own
		elif own != null:
			unit.inventory.remove_at(unit_slot)
			partner.inventory.append(own)
		else:
			partner.inventory.remove_at(partner_slot)
			unit.inventory.append(theirs)
		state.mark_changed()

	func to_dict() -> Dictionary:
		return {"type": "trade", "unit": String(unit_id), "slot": unit_slot, "partner": String(partner_id), "partner_slot": partner_slot}
