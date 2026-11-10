class_name DefeatRules
extends RefCounted
## What happens when a unit falls (spec §8.4, §9.1).
##
## The unit leaves the map. Units of human-controlled factions retreat
## (flagged [member UnitState.retreated]; back next map) instead of dying,
## since permadeath is out of scope. Items marked as drops go to the unit
## that defeated it if it has room; otherwise they are lost (no convoy yet).
## Protagonist defeat (game over) is a defeat condition handled by the turn
## loop's objectives (M4).
##
## Extension point: permadeath replaces the retreat flag here.


## Result of a defeat: items handed over and items lost for lack of space.
class Outcome:
	extends RefCounted
	var unit_id: StringName
	var by_unit_id: StringName = &""
	var items_given: Array[ItemData] = []
	var items_lost: Array[ItemData] = []


## Removes [param unit] from the map and hands its drops to [param killer].
static func apply(state: BattleState, unit: UnitState, killer: UnitState) -> Outcome:
	var outcome := Outcome.new()
	outcome.unit_id = unit.id
	outcome.by_unit_id = killer.id if killer != null else &""
	unit.current_hp = 0
	state.remove_from_map(unit.id)
	var faction: FactionData = state.get_faction(unit.faction_id)
	if faction != null and faction.controller == FactionData.Controller.HUMAN:
		unit.retreated = true
	for slot: InventorySlot in unit.inventory:
		if not slot.drops:
			continue
		if killer != null and killer.is_alive() and killer.has_inventory_space(state.ruleset):
			var given: InventorySlot = slot.copy()
			given.drops = false
			killer.inventory.append(given)
			outcome.items_given.append(slot.item)
		else:
			outcome.items_lost.append(slot.item)
	return outcome
